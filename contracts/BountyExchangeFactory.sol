//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./BountyExchangeProduct.sol";

/// @title BountyExchangeFactory
/// @author ashishbabar
/// @notice This is contract creates a new bounty contract as per input
/// @dev This is factory contract which generated BountyExchange contract per bounty request
contract BountyExchangeFactory {
    event BountyCreated(uint256 requestID);

    // Array to maintain Product instances
    mapping(uint256 => address) public bountyRequests;

    /// @notice CreateBountyRequest function accepts stolenAmount
    /// @dev This function accepts configuration and deploys new contract
    /// @param stolenAmount Amount stolen
    /// @param stolenToken Token address stolen
    /// @param bountyAmount Requested bounty amount
    /// @param bountyToken Request boubny amount token address
    /// @param bountyProvider Wallet address of bounty provider
    /// @param duration validity of request
    /// @return Documents the return variables of a contract’s function state variable
    function createBountyRequest(
        uint256 stolenAmount,
        address stolenToken,
        uint256 bountyAmount,
        address bountyToken,
        address bountyProvider,
        uint256 duration
    ) public returns (uint256) {
        // Generate requestID from hash of request body
        uint256 requestID = hashBountyRequest(
            stolenAmount,
            stolenToken,
            bountyAmount,
            bountyToken,
            msg.sender
        );
        BountyExchangeProduct bountyExchangeProduct = new BountyExchangeProduct(
            stolenAmount,
            stolenToken,
            bountyAmount,
            bountyToken,
            bountyProvider,
            duration
        );
        bountyRequests[requestID] = address(bountyExchangeProduct);
        emit BountyCreated(requestID);
        return requestID;
    }

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
}
