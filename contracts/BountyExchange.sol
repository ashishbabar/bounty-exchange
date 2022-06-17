//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title BountyExchange is contract that settles exchange of stolen tokens and bounty
/// within untrusted parties
/// @author ashishbabar
/// @notice This contract has functionalities that provides secure and trustworthy way
/// to exchange stolen tokens with bounty
/// TODO: Need to restrict access to submitBounty to wallet provided by SA.
contract BountyExchange {
    using Timers for Timers.Timestamp;
    using SafeCast for uint256;

    struct BountyRequest {
        uint256 stolenAmount;
        uint256 bountyAmount;
        address stolenToken;
        address bountyToken;
        address bountyReceiver;
        address bountyProvider;
        bool bountyProcessed;
        Timers.Timestamp expirationTimestamp;
    }
    mapping(uint256 => BountyRequest) public bountyRequests;

    event BountyRequested(uint256 requestId);
    event BountySubmitted(uint256 requestId, bool status);
    event TokensClaimed(uint256 requestId);

    constructor() {}

    function hashBountyRequest(
        uint256 stolenAmount,
        address stolenToken,
        uint256 bountyAmount,
        address bountyToken,
        address bountyReceiver
    ) private pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        stolenAmount,
                        stolenToken,
                        bountyAmount,
                        bountyToken,
                        bountyReceiver
                    )
                )
            );
    }

    function getBountyRequest(uint256 requestID)
        public
        view
        returns (
            uint256,
            address,
            uint256,
            address,
            address,
            bool
        )
    {
        BountyRequest storage bountyRequest = bountyRequests[requestID];
        return (
            bountyRequest.stolenAmount,
            bountyRequest.stolenToken,
            bountyRequest.bountyAmount,
            bountyRequest.bountyToken,
            bountyRequest.bountyReceiver,
            bountyRequest.bountyProcessed
        );
    }

    // This function is expecting that security analyst have already allowed tokens to this contract.
    // TODO: similar type parameters needs to be clubbed together.
    function requestBounty(
        uint256 stolenAmount,
        address stolenToken,
        uint256 bountyAmount,
        address bountyToken,
        address bountyProvider,
        uint256 duration
    ) public returns (uint256) {
        // TODO Check if stolenToken and bountyToken are ERC20 tokens.
        // Check stolen token allowance
        uint256 stolenTokenAllowance = IERC20(stolenToken).allowance(
            msg.sender,
            address(this)
        );
        require(stolenTokenAllowance == stolenAmount, "Insufficient allowance");

        // Generate requestID from hash of request body
        uint256 requestID = hashBountyRequest(
            stolenAmount,
            stolenToken,
            bountyAmount,
            bountyToken,
            msg.sender
        );

        // Calculate expiration timestamp from deadline
        uint64 expirationTimestamp = block.timestamp.toUint64() +
            duration.toUint64();

        // Initialize bounty request in storage
        BountyRequest storage bountyRequest = bountyRequests[requestID];
        bountyRequest.stolenAmount = stolenAmount;
        bountyRequest.stolenToken = stolenToken;
        bountyRequest.bountyAmount = bountyAmount;
        bountyRequest.bountyToken = bountyToken;
        bountyRequest.bountyReceiver = msg.sender;
        bountyRequest.bountyProvider = bountyProvider;
        bountyRequest.bountyProcessed = false;
        bountyRequest.expirationTimestamp.setDeadline(expirationTimestamp);

        // Get funds from SAs allowance to contract
        IERC20(stolenToken).transferFrom(
            msg.sender,
            address(this),
            stolenAmount
        );
        emit BountyRequested(requestID);

        return requestID;
    }

    // This function will be executed by Bounty provider.
    // This also indicates that bounty provider have agreed to terms and have approved requested bounty to contract
    function submitBounty(uint256 bountyRequestID) public returns (bool) {
        BountyRequest storage bountyRequest = bountyRequests[bountyRequestID];

        // Check if msg.sender is bounty provider
        require(bountyRequest.bountyProvider == msg.sender, "Not allowed");

        // Check if bounty request is expired
        require(
            bountyRequest.expirationTimestamp.getDeadline() >
                block.timestamp.toUint64(),
            "Bounty request expired!"
        );

        // Retrieve tokens from bounty token contract
        uint256 approvedBountyAmount = IERC20(bountyRequest.bountyToken)
            .allowance(msg.sender, address(this));

        // Check if bounty tokens (USDT) are approved to this contract
        require(
            approvedBountyAmount == bountyRequest.bountyAmount,
            "Insufficient allowance"
        );

        // Transfer funds from Bounty providers allowance to contract
        IERC20(bountyRequest.bountyToken).transferFrom(
            msg.sender,
            address(this),
            approvedBountyAmount
        );

        // Transfer funds from contract to bounty requester
        IERC20(bountyRequest.bountyToken).transfer(
            bountyRequest.bountyReceiver,
            approvedBountyAmount
        );

        // Settle stolen funds
        IERC20(bountyRequest.stolenToken).transfer(
            msg.sender,
            bountyRequest.stolenAmount
        );

        // Mark this request as processed.
        bountyRequest.bountyProcessed = true;

        emit BountySubmitted(bountyRequestID, bountyRequest.bountyProcessed);
        return bountyRequest.bountyProcessed;
    }

    // This function is for SA to claim tokens from expired bounty request
    function claimTokensFromExpiredBounty(uint256 bountyRequestID)
        public
        returns (bool)
    {
        BountyRequest storage bountyRequest = bountyRequests[bountyRequestID];

        // Check if caller has requested bounty request
        require(bountyRequest.bountyReceiver == msg.sender, "Not allowed");

        // Check if bounty is expired
        require(
            block.timestamp.toUint64() >
                bountyRequest.expirationTimestamp.getDeadline(),
            "Bounty is not expired"
        );

        // Tranfer stolen tokens back to requester
        IERC20(bountyRequest.stolenToken).transfer(
            msg.sender,
            bountyRequest.stolenAmount
        );

        // Emit event
        emit TokensClaimed(bountyRequestID);

        return true;
    }

    // This function checks if bountyRequest is expired
    function isBountyExpired(uint256 bountyRequestID)
        public
        view
        returns (bool)
    {
        BountyRequest storage bountyRequest = bountyRequests[bountyRequestID];
        return
            block.timestamp.toUint64() >
            bountyRequest.expirationTimestamp.getDeadline();
    }

    // This function fetches deadline of bounty request
    function getBountyDeadline(uint256 bountyRequestID)
        public
        view
        returns (uint64)
    {
        BountyRequest storage bountyRequest = bountyRequests[bountyRequestID];
        return bountyRequest.expirationTimestamp.getDeadline();
    }
}
