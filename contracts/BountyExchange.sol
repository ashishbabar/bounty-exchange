//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

/// @title A title that should describe the contract/interface
/// @author ashishbabar
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract BountyExchange {
    struct BountyRequest {
        uint256 stolenAmount;
        uint256 bountyAmount;
        address stolenToken;
        address bountyToken;
        address bountyReceiver;
        bool bountyProcessed;
    }
    mapping(uint256 => BountyRequest) public bountyRequests;

    event RequestBounty(uint256 requestId);
    event SubmitBounty(uint256 requestId, bool status);

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
    function requestBounty(
        uint256 stolenAmount,
        address stolenToken,
        uint256 bountyAmount,
        address bountyToken
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

        // Initialize bounty request in storage
        BountyRequest storage bountyRequest = bountyRequests[requestID];
        bountyRequest.stolenAmount = stolenAmount;
        bountyRequest.stolenToken = stolenToken;
        bountyRequest.bountyAmount = bountyAmount;
        bountyRequest.bountyToken = bountyToken;
        bountyRequest.bountyReceiver = msg.sender;
        bountyRequest.bountyProcessed = false;

        IERC20(stolenToken).transferFrom(
            msg.sender,
            address(this),
            stolenAmount
        );
        emit RequestBounty(requestID);

        return requestID;
    }

    // This function will be executed by Bounty provider.
    // This also indicates that bounty provider have agreed to terms and have approved requested bounty to contract
    function submitBounty(uint256 bountyRequestID) public returns (bool) {
        BountyRequest storage bountyRequest = bountyRequests[bountyRequestID];

        // Retrieve tokens from bounty token contract
        uint256 approvedBountyAmount = IERC20(bountyRequest.bountyToken)
            .allowance(msg.sender, address(this));

        // Check if bounty tokens (USDT) are approved to this contract
        require(
            approvedBountyAmount == bountyRequest.bountyAmount,
            "Insufficient allowance"
        );

        // Settle bounty funds
        IERC20(bountyRequest.bountyToken).transferFrom(
            msg.sender,
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

        emit SubmitBounty(bountyRequestID, bountyRequest.bountyProcessed);
        return bountyRequest.bountyProcessed;
    }
}
