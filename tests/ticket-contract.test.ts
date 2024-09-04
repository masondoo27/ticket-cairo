import { describe, expect, test } from "@jest/globals";
import { Account, Contract, RpcProvider } from "starknet";
import * as dotenv from "dotenv";
dotenv.config();
const provider = new RpcProvider({ nodeUrl: process.env.RPC });

describe("Ticket contract", () => {
  let buyer: Account;
  let ticketContract: Contract;
  let paymentContract: Contract;
  let ticketsPerLot = 10;
  let ticketPrice = BigInt(0.001 * 1e18);
  beforeAll(async () => {
    buyer = new Account(
      provider,
      process.env.BUYER_ACCOUNT_ADDRESS!,
      process.env.BUYER_ACCOUNT_PRIVATE_KEY!
    );
    {
      const { abi: testAbi } = await provider.getClassAt(
        process.env.TICKET_ADDRESS!
      );
      if (testAbi === undefined) {
        throw new Error("No ABI found for the contract.");
      }

      ticketContract = new Contract(
        testAbi,
        process.env.TICKET_ADDRESS!,
        provider
      ).typedv2(testAbi);
    }
    {
      const { abi: testAbi } = await provider.getClassAt(
        process.env.PAYMENT_ADDRESS!
      );
      if (testAbi === undefined) {
        throw new Error("No ABI found for the contract.");
      }

      paymentContract = new Contract(
        testAbi,
        process.env.PAYMENT_ADDRESS!,
        provider
      ).typedv2(testAbi);
    }
  });
  it("should allow users to purchase tickets", async function () {
    const numberOfLotBuy = 1;
    const numberOfTicketsToPurchase = ticketsPerLot * numberOfLotBuy;
    const totalCost = ticketPrice * BigInt(numberOfLotBuy);

    // Buyer Approve OpenMark payment token
    {
      paymentContract.connect(buyer);
      let tx = await paymentContract.approve(ticketContract.address, totalCost);
      const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
      if (txReceipt.isSuccess()) {
        console.log("Approve Payment Succeed!");
      }
    }

    // Buyer Purchase Ticket
    {
      let buyerBeforeBalance = await paymentContract.balanceOf(buyer.address);
      ticketContract.connect(buyer);
      let tx = await ticketContract.buyTickets(numberOfTicketsToPurchase);
      const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
      if (txReceipt.isSuccess()) {
        console.log("Purchase Ticket Succeed!");
      }
      let buyerAfterBalance = await paymentContract.balanceOf(buyer.address);
      expect(buyerAfterBalance).toEqual(buyerBeforeBalance - totalCost);
    }
  }, 300_000);
});
