import { describe, expect, test } from "@jest/globals";
import { Account, Contract, RpcProvider } from "starknet";
import * as dotenv from "dotenv";
dotenv.config();
const provider = new RpcProvider({ nodeUrl: process.env.RPC });

describe("Ticket contract", () => {
  let buyer: Account;
  let ticketContract: Contract;
  let paymentContract: Contract;
  let ticketsPerLot: bigint = BigInt(0);
  let ticketPrice: bigint = BigInt(0);
  let discount5: bigint = BigInt(0);
  let discount10: bigint = BigInt(0);
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

      ticketsPerLot = await ticketContract.getTicketPerLot();
      ticketsPerLot = BigInt(ticketsPerLot);
      ticketPrice = await ticketContract.getTicketPrice();
      ticketPrice = BigInt(ticketPrice);
      discount5 = await ticketContract.getDiscount5();
      discount5 = BigInt(discount5);
      discount10 = await ticketContract.getDiscount10();
      discount10 = BigInt(discount10);

      console.log("ticketsPerLot: ", ticketsPerLot);
      console.log("ticketPrice: ", ticketPrice);
      console.log("discount5: ", discount5);
      console.log("discount10: ", discount10);
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
  }, 60_000);
  it("getCost should return the correct cost", async function () {
    const cost = await ticketContract.getCost(1);
    expect(cost).toEqual(ticketPrice * BigInt(ticketsPerLot));
  });
  it("discount5 should work", async function () {
    const lot = 5;
    const cost = await ticketContract.getCost(lot);
    const expectCost = ticketPrice * BigInt(ticketsPerLot) * BigInt(lot);
    expect(cost).toEqual(
      expectCost - (expectCost * BigInt(discount5)) / BigInt(100)
    );
  });
  it("discount10 should work", async function () {
    const lot = 10;
    const cost = await ticketContract.getCost(lot);
    const expectCost = ticketPrice * BigInt(ticketsPerLot) * BigInt(lot);
    expect(cost).toEqual(
      expectCost - (expectCost * BigInt(discount10)) / BigInt(100)
    );
  });
  it("should allow users to purchase tickets", async function () {
    const numberOfLotBuy = BigInt(1);
    const numberOfTicketsToPurchase = ticketsPerLot * numberOfLotBuy;
    const totalCost = ticketPrice * BigInt(numberOfTicketsToPurchase);

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
      let tx = await ticketContract.buyTickets(numberOfLotBuy, 1);
      const txReceipt = await provider.waitForTransaction(tx.transaction_hash);
      if (txReceipt.isSuccess()) {
        console.log("Purchase Ticket Succeed!");
      }
      let buyerAfterBalance = await paymentContract.balanceOf(buyer.address);
      expect(buyerAfterBalance).toEqual(buyerBeforeBalance - totalCost);
    }
  }, 300_000);
});
