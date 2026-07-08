// supabase/functions/get-balances/index.ts
//
// Deploy with: supabase functions deploy get-balances
// Call with:   supabase.functions.invoke('get-balances', { body: { groupId } })
//
// This is where the "custom mathematical logic" from the original spec lives —
// the net balances themselves are just a SQL aggregate (see get_net_balances
// in schema.sql), but reducing them to the minimum number of transactions is
// real server-side logic, kept out of the database and easy to unit-test.

import { serve } from "https://deno.land/std@0.190.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Balance = { user_id: string; net: number };
type Transaction = { from: string; to: string; amount: number };

const EPSILON = 0.01;

function simplifyDebts(balances: Balance[]): Transaction[] {
  // Greedy match: biggest debtor against biggest creditor, repeat.
  // For a stricter minimum-transaction guarantee under floating point noise,
  // swap these sorted arrays for a max-heap that re-inserts the remainder —
  // for typical group sizes (a handful to a few dozen people) this sorted
  // version already produces at most n-1 transactions in practice.
  const debtors = balances
    .filter((b) => b.net < -EPSILON)
    .map((b) => ({ id: b.user_id, amount: -b.net }))
    .sort((a, b) => b.amount - a.amount);

  const creditors = balances
    .filter((b) => b.net > EPSILON)
    .map((b) => ({ id: b.user_id, amount: b.net }))
    .sort((a, b) => b.amount - a.amount);

  const transactions: Transaction[] = [];
  let i = 0;
  let j = 0;

  while (i < debtors.length && j < creditors.length) {
    const debtor = debtors[i];
    const creditor = creditors[j];
    const settled = Math.min(debtor.amount, creditor.amount);

    transactions.push({
      from: debtor.id,
      to: creditor.id,
      amount: Math.round(settled * 100) / 100,
    });

    debtor.amount -= settled;
    creditor.amount -= settled;

    if (debtor.amount <= EPSILON) i++;
    if (creditor.amount <= EPSILON) j++;
  }

  return transactions;
}

serve(async (req: Request) => {
  try {
    const { groupId } = await req.json();
    if (!groupId) {
      return new Response(JSON.stringify({ error: "groupId is required" }), { status: 400 });
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401 });
    }

    // Forward the caller's JWT so RLS applies to every query this function makes.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
    }

    // Confirm the requester is actually in this group before computing anything.
    const { data: membership, error: memErr } = await supabase
      .from("group_members")
      .select("id")
      .eq("group_id", groupId)
      .eq("user_id", userData.user.id)
      .maybeSingle();

    if (memErr || !membership) {
      return new Response(JSON.stringify({ error: "Not a member of this group" }), { status: 403 });
    }

    const { data: balances, error: balErr } = await supabase.rpc("get_net_balances", {
      p_group_id: groupId,
    });

    if (balErr) {
      return new Response(JSON.stringify({ error: balErr.message }), { status: 500 });
    }

    const transactions = simplifyDebts(balances ?? []);

    return new Response(JSON.stringify({ groupId, transactions }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500 });
  }
});
