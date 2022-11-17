//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.16;
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
contract BountyExchangeProduct {
    using Timers for Timers.Timestamp;
    using SafeCast for uint256;

    uint256 public stolenAmount;
    uint256 public bountyAmount;
    address public stolenToken;
    address public bountyToken;
    address public bountyReceiver;
    address public bountyProvider;
    bool public bountyProcessed;
    bool public bountyRequested;
    Timers.Timestamp public expirationTimestamp;

    event BountySubmitted(bool status);
    event BountyRequested(bool status);
    event TokensClaimed();

    constructor(
        uint256 _stolenAmount,
        address _stolenToken,
        uint256 _bountyAmount,
        address _bountyToken,
        address _bountyProvider,
        uint256 _duration
    ) {
        // Calculate expiration timestamp from deadline
        uint64 _expirationTimestamp = block.timestamp.toUint64() +
            _duration.toUint64();

        // Initialize bounty request in storage
        stolenAmount = _stolenAmount;
        stolenToken = _stolenToken;
        bountyAmount = _bountyAmount;
        bountyToken = _bountyToken;
        bountyReceiver = msg.sender;
        bountyProvider = _bountyProvider;
        bountyProcessed = false;
        bountyRequested = false;
        expirationTimestamp.setDeadline(_expirationTimestamp);
    }

    function requestBounty() public {
        // TODO Check if stolenToken and bountyToken are ERC20 tokens.
        // Check stolen token allowance
        uint256 stolenTokenAllowance = IERC20(stolenToken).allowance(
            msg.sender,
            address(this)
        );
        console.log("In contract stolenTokenAllowance ", stolenTokenAllowance);
        console.log("In contract stolen token amount ", stolenAmount);
        require(stolenTokenAllowance == stolenAmount, "Insufficient allowance");

        // Get funds from SAs allowance to contract
        IERC20(stolenToken).transferFrom(
            msg.sender,
            address(this),
            stolenAmount
        );
        bountyRequested = true;
        emit BountySubmitted(bountyRequested);
    }

    function getBountyRequest()
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
        return (
            stolenAmount,
            stolenToken,
            bountyAmount,
            bountyToken,
            bountyReceiver,
            bountyProcessed
        );
    }

    // This function is expecting that security analyst have already allowed tokens to this contract.
    // TODO: similar type parameters needs to be clubbed together.
    // function requestBounty(
    //     uint256 stolenAmount,
    //     address stolenToken,
    //     uint256 bountyAmount,
    //     address bountyToken,
    //     address bountyProvider,
    //     uint256 duration
    // ) public returns (uint256) {
    //     // TODO Check if stolenToken and bountyToken are ERC20 tokens.
    //     // Check stolen token allowance
    //     uint256 stolenTokenAllowance = IERC20(stolenToken).allowance(
    //         msg.sender,
    //         address(this)
    //     );
    //     require(stolenTokenAllowance == stolenAmount, "Insufficient allowance");

    //     // Generate requestID from hash of request body
    //     uint256 requestID = hashBountyRequest(
    //         stolenAmount,
    //         stolenToken,
    //         bountyAmount,
    //         bountyToken,
    //         msg.sender
    //     );

    //     // Calculate expiration timestamp from deadline
    //     uint64 expirationTimestamp = block.timestamp.toUint64() +
    //         duration.toUint64();

    //     // Initialize bounty request in storage
    //     BountyRequest storage bountyRequest = bountyRequests[requestID];
    //     bountyRequest.stolenAmount = stolenAmount;
    //     bountyRequest.stolenToken = stolenToken;
    //     bountyRequest.bountyAmount = bountyAmount;
    //     bountyRequest.bountyToken = bountyToken;
    //     bountyRequest.bountyReceiver = msg.sender;
    //     bountyRequest.bountyProvider = bountyProvider;
    //     bountyRequest.bountyProcessed = false;
    //     bountyRequest.expirationTimestamp.setDeadline(expirationTimestamp);

    //     // Get funds from SAs allowance to contract
    //     IERC20(stolenToken).transferFrom(
    //         msg.sender,
    //         address(this),
    //         stolenAmount
    //     );
    //     emit BountyRequested(requestID);

    //     return requestID;
    // }

    // This function will be executed by Bounty provider.
    // This also indicates that bounty provider have agreed to terms and have approved requested bounty to contract
    function submitBounty() public returns (bool) {
        // Check if bounty is processed
        require(bountyProcessed == false, "Bounty processed");

        // Check if msg.sender is bounty provider
        require(bountyProvider == msg.sender, "Not allowed");

        // Check if bounty request is expired
        require(
            expirationTimestamp.getDeadline() > block.timestamp.toUint64(),
            "Bounty request expired!"
        );

        // Retrieve tokens from bounty token contract
        uint256 approvedBountyAmount = IERC20(bountyToken).allowance(
            msg.sender,
            address(this)
        );

        // Check if bounty tokens (USDT) are approved to this contract
        // TODO: Implement taxation logic
        require(approvedBountyAmount == bountyAmount, "Insufficient allowance");

        // Transfer funds from Bounty providers allowance to contract
        IERC20(bountyToken).transferFrom(
            msg.sender,
            address(this),
            approvedBountyAmount
        );

        // Transfer funds from contract to bounty requester
        IERC20(bountyToken).transfer(bountyReceiver, approvedBountyAmount);

        // Settle stolen funds
        IERC20(stolenToken).transfer(msg.sender, stolenAmount);

        // Mark this request as processed.
        bountyProcessed = true;

        emit BountySubmitted(bountyProcessed);
        return bountyProcessed;
    }

    // This function is for SA to claim tokens from expired bounty request
    function claimTokensFromExpiredBounty() public returns (bool) {
        // Check if caller has requested bounty request
        require(bountyReceiver == msg.sender, "Not allowed");

        // Check if bounty is expired
        require(
            block.timestamp.toUint64() > expirationTimestamp.getDeadline(),
            "Bounty is not expired"
        );

        // Tranfer stolen tokens back to requester
        IERC20(stolenToken).transfer(msg.sender, stolenAmount);

        // Emit event
        emit TokensClaimed();

        return true;
    }

    // This function checks if bountyRequest is expired
    function isBountyExpired() public view returns (bool) {
        return block.timestamp.toUint64() > expirationTimestamp.getDeadline();
    }

    // This function fetches deadline of bounty request
    function getBountyDeadline() public view returns (uint64) {
        return expirationTimestamp.getDeadline();
    }
}
