import { expect } from "chai";
import { BigNumber, ContractReceipt } from "ethers";
import { ethers, network } from "hardhat";
import { Contract, ContractFactory, Signer } from "ethers";

describe("BountyExchange", function () {
  let BountyExchangeFactory: ContractFactory;
  let TokenFactory: ContractFactory;
  let stolenToken: Contract;
  let bountyToken: Contract;
  let BountyExchange: Contract;

  let stolenAmount = BigNumber.from("100");
  let bountyAmount = BigNumber.from("100");

  let bountyRequest: string;
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
    BountyExchangeFactory = await ethers.getContractFactory("BountyExchange");
    BountyExchange = await BountyExchangeFactory.deploy();
    await BountyExchange.deployed();

    // transfer funds to bounty requester
    await stolenToken.transfer(bountyRequester.address, stolenAmount);

    // transfer funds to bounty provider
    await bountyToken.transfer(bountyProvider.address, bountyAmount);

    // Approve funds from bountyRequester to contract
    await stolenToken
      .connect(bountyRequester)
      .approve(BountyExchange.address, stolenAmount);

    // Create 1 day duration bignumber object
    const durationBigNumber = BigNumber.from("86400");

    // Request bounty
    const requestBountyResponse = await BountyExchange.connect(
      bountyRequester
    ).requestBounty(
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
    const requestBountyEvent = requestBountyReceipt.events?.find((x) => {
      return x.event == "BountyRequested";
    });

    // Extract arguments from extract event details
    const args = requestBountyEvent?.args;

    // bountyRequest = await BountyExchange.getBountyRequest(args ? args.requestId : "");
    bountyRequest = args ? args.requestId : "";
  });

  it("Should create a bounty request", async function () {
    const stolenTokenContractBalance = await stolenToken.balanceOf(
      BountyExchange.address
    );
    expect(stolenTokenContractBalance).to.equals(stolenAmount);
  });

  it("Should submit bounty", async function () {
    const [, bountyRequester, bountyProvider] = await ethers.getSigners();
    await bountyToken
      .connect(bountyProvider)
      .approve(BountyExchange.address, bountyAmount);

    const bountySubmissionTx = await BountyExchange.connect(
      bountyProvider
    ).submitBounty(bountyRequest);

    const submitBountyReceipt = await bountySubmissionTx.wait();

    const bountyRequesterBalance = await bountyToken.balanceOf(
      bountyRequester.address
    );
    expect(bountyRequesterBalance).to.equals(bountyAmount);

    const bountyProviderBalance = await stolenToken.balanceOf(
      bountyProvider.address
    );
    expect(bountyProviderBalance).to.equals(stolenAmount);

    // Check if bounty request is processed.
    const bountyRequestResponse = await BountyExchange.getBountyRequest(
      bountyRequest
    );
    expect(bountyRequestResponse[5]).to.equal(true);

    // Check event emitted
    const submitBountyEvent = await submitBountyReceipt.events?.find((x:any)=>{
      return x.event == "BountySubmitted";
    });

    const args = submitBountyEvent?.args;

    const submitBountyRequestId = args ? args.requestId : "";
    const submitBountyStatus = args ? args.status : "";

    expect(submitBountyRequestId).to.equals(bountyRequest);
    expect(submitBountyStatus).to.be.true;
  });

  it("Should detect expired bounty request", async function () {
    const bountyDeadline = await BountyExchange.getBountyDeadline(
      bountyRequest
    );
    const currentTimestamp = Math.round(new Date().getTime() / 1000);

    await network.provider.send("evm_increaseTime", [
      bountyDeadline.toNumber() - currentTimestamp,
    ]);
    await network.provider.send("evm_mine");

    const isBountyExpired = await BountyExchange.isBountyExpired(bountyRequest);
    expect(isBountyExpired).to.equals(true);
  });

  it("Should claim tokens from expired bounty request", async function () {
    const [, bountyRequester] = await ethers.getSigners();
    const bountyDeadline = await BountyExchange.getBountyDeadline(
      bountyRequest
    );
    const currentTimestamp = Math.round(new Date().getTime() / 1000);

    await network.provider.send("evm_increaseTime", [
      bountyDeadline.toNumber() - currentTimestamp,
    ]);
    await network.provider.send("evm_mine");

    const claimTokensTransaction = await BountyExchange.connect(bountyRequester).claimTokensFromExpiredBounty(
      bountyRequest
    );

    const claimTokenTransactionReceipt = await claimTokensTransaction.wait();

    const bountyRequesterBalance = await stolenToken.balanceOf(
      bountyRequester.address
    );
    expect(bountyRequesterBalance).to.equal(stolenAmount);

    // Check events
    const claimedTokenEvent = claimTokenTransactionReceipt.events?.find((x:any)=>{
      return x.event == "TokensClaimed";
    })

    const claimedTokensEventRequestID = claimedTokenEvent?.args ? claimedTokenEvent.args.requestId : "";

    expect(claimedTokensEventRequestID).to.equals(bountyRequest);
  });
});
