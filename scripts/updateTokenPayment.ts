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

  const updateTokenAddress = ticketContract.populate("updateTokenAddress", [
    process.env.PAYMENT_ADDRESS!,
  ]);
  const res = await ticketContract.updateTokenAddress(
    updateTokenAddress.calldata
  );
  console.log("Transaction hash: " + res.transaction_hash);
  await provider.waitForTransaction(res.transaction_hash);
}
updateConfig();
