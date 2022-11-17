import { expect } from "chai";
import { BigNumber, ContractReceipt } from "ethers";
import { ethers, network } from "hardhat";
import { Contract, ContractFactory, Signer } from "ethers";

describe("BountyExchange", function () {
  let BountyExchangeFactoryFactory: ContractFactory;
  let TokenFactory: ContractFactory;
  let stolenToken: Contract;
  let bountyToken: Contract;
  let BountyExchange: Contract;
  let BountyExchangeFactory: Contract;
  let BountyExchangeProductFactory: ContractFactory;
  let bountyExchangeProduct: Contract;

  let stolenAmount = BigNumber.from("100");
  let bountyAmount = BigNumber.from("100");
  let bountyRequest: BigNumber;

  this.beforeEach(async () => {
    const [, bountyRequester, bountyProvider] = await ethers.getSigners();
    TokenFactory = await ethers.getContractFactory("MyToken");
    bountyToken = await TokenFactory.deploy(
      "Tether USD",
      "USDT",
      "1000000000000000000000"
    );
    stolenToken = await TokenFactory.deploy(
      "W Token",
      "WTOK",
      "1000000000000000000000"
    );
    BountyExchangeFactoryFactory = await ethers.getContractFactory(
      "BountyExchangeFactory"
    );
    BountyExchangeFactory = await BountyExchangeFactoryFactory.deploy();
    await BountyExchangeFactory.deployed();

    BountyExchangeProductFactory = await ethers.getContractFactory(
      "BountyExchangeProduct"
    );
    // transfer funds to bounty requester
    await stolenToken.transfer(bountyRequester.address, stolenAmount);

    // transfer funds to bounty provider
    await bountyToken.transfer(bountyProvider.address, bountyAmount);

    // Create 1 day duration bignumber object
    const durationBigNumber = BigNumber.from("86400");

    // Request bounty
    const requestBountyResponse = await BountyExchangeFactory.connect(
      bountyRequester
    ).createBountyRequest(
      stolenAmount,
      stolenToken.address,
      bountyAmount,
      bountyToken.address,
      bountyProvider.address,
      durationBigNumber
    );

    // Fetch contract receipt
    const requestBountyReceipt: ContractReceipt =
      await requestBountyResponse.wait();

    // Extract event from receipt
    const bountyCreatedEvent = requestBountyReceipt.events?.find((x) => {
      return x.event == "BountyCreated";
    });

    // Extract arguments from extract event details
    const args = bountyCreatedEvent?.args;

    // bountyRequest = await BountyExchange.getBountyRequest(args ? args.requestId : "");
    bountyRequest = args ? args[0] : "";
  });

  it("Should create a bounty request", async function () {
    console.log("bountyRequest :>> ", bountyRequest);
    // const productAddress = await BountyExchangeFactory.bountyRequests(bountyRequest.toString())
    // const bountyExchangeProduct = BountyExchangeProductFactory.attach(productAddress);
    // bountyExchangeProduct.requestBounty
  });
  it("Should request bounty", async function () {
    const [, bountyRequester, bountyProvider] = await ethers.getSigners();

    const productAddress = await BountyExchangeFactory.bountyRequests(
      bountyRequest.toString()
    );

    // Approve funds from bountyRequester to contract
    await stolenToken
      .connect(bountyRequester)
      .approve(productAddress, stolenAmount);

    const bountyExchangeProduct =
      BountyExchangeProductFactory.attach(productAddress);
    const allowance = await stolenToken.allowance(
      bountyRequester.address,
      productAddress
    );
    const bountyRequestedTx = await bountyExchangeProduct
      .connect(bountyRequester)
      .requestBounty();
    // Fetch contract receipt
    const requestBountyReceipt: ContractReceipt =
      await bountyRequestedTx.wait();
    const bountyRequestedEvent = requestBountyReceipt.events?.find((x) => {
      return x.event == "BountyRequested";
    });

    // Extract arguments from extract event details
    const args = bountyRequestedEvent?.args;

    // bountyRequest = await BountyExchange.getBountyRequest(args ? args.requestId : "");
    console.log("bountyRequestStatus :>> ", args);
  });
});
