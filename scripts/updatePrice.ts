import { Account, Contract, RpcProvider } from "starknet";
import * as dotenv from "dotenv";
dotenv.config();
const provider = new RpcProvider({ nodeUrl: process.env.RPC });

async function updateConfig() {
  const owner = new Account(
    provider,
    process.env.BUYER_ACCOUNT_ADDRESS!,
    process.env.BUYER_ACCOUNT_PRIVATE_KEY!
  );
  const { abi: testAbi } = await provider.getClassAt(
    process.env.TICKET_ADDRESS!
  );
  if (testAbi === undefined) {
    throw new Error("No ABI found for the contract.");
  }

  const ticketContract = new Contract(
    testAbi,
    process.env.TICKET_ADDRESS!,
    provider
  ).typedv2(testAbi);

  ticketContract.connect(owner);

  const updatePrice = ticketContract.populate("updateTicketPrice", [
    BigInt(0.001 * 1e18),
  ]);
  const res2 = await ticketContract.updateTicketPrice(updatePrice.calldata);
  console.log("Transaction hash: " + res2.transaction_hash);
  await provider.waitForTransaction(res2.transaction_hash);
}
updateConfig();
