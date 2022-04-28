# Bounty Exchange

This is the implementation for Bounty exchange smart contract. 

This smart contract helps security analyst who manages to steal tokens from DeFi contracts to claim bounty securily. 

Providing bounty and returning back the stolen funds is very challenging in crypto space. Two untrustworthy parties wants to do an exchange without any strings attached. Most of the hacks happenening in this space has this hurdle of exchanging bounty with stolen funds. Bounty exchange helps in solving this problem.

Exchange contract holds logic to record bounty request for bounty providers. Once bounty requester places this bounty request, stolen funds will be locked in exchange contract for that limited time window. Bounty requester will receive a request id which is to be shared with bounty provider. Bounty provider will verify the bounty request and send funds to contracts with submit bounty function. Contract will verify bounty and will distribute funds to respective receivers.
