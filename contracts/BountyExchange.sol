//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
/// @title A title that should describe the contract/interface
/// @author ashishbabar
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract BountyExchange {
    string private greeting;
    struct BountyRequest {
        uint256 stolenAmount;
        uint256 bountyAmount;
        address stolenToken;
        address bountyToken;
    }
    mapping(uint256 => BountyRequest) public bountyRequests;
    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting; ̰
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function hashBountyRequest(uint256 stolenAmount, address stolenToken, uint256 bountyAmount, address bountyToken) public returns(uint256){
        return uint256(keccak256(abi.encode(stolenAmount,stolenToken,bountyAmount,bountyToken)));
    }
    // This function is expecting that security analyst have already allowed tokens to this contract.
    function requestBounty(uint256 stolenAmount, address stolenToken, uint256 bountyAmount, address bountyToken) public returns(uint256){
        // TODO Check if stolenToken and bountyToken are ERC20 tokens.
        // Check stolen token allowance
        uint256 stolenTokenAllowance = IERC20(stolenToken).allowance(msg.sender,address(this));
        require(stolenTokenAllowance == stolenAmount, "Insufficient allowance");
        uint256 requestID = hashBountyRequest(stolenAmount,stolenToken,bountyAmount,bountyToken);
        BountyRequest storage bountyRequest = bountyRequests[requestID];
        bountyRequest.stolenAmount=stolenAmount;
        bountyRequest.stolenToken=stolenToken;
        bountyRequest.bountyAmount=bountyAmount;
        bountyRequest.bountyToken=bountyToken;
        return requestID
    }
}
