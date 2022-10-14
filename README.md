# Debond-Exchange 

Contract for issuing P2P bonds for auctions.  

## Deps: 
this package is  defined in hardhat + Foundry. credits to [pcaversarrico](https://github.com/pcaversaccio/hardhat-project-template-ts) for the repo.

## Status bar:


## features: 
- add .env file with the private environment variables for the deployment chain .
- for mainnet forking, define the parameter `process.env.**` where the remaining part will be the URL for the specified chain, also you can define the initial blockNumber in order to optimize the storage reference of the blocks.
- also it provides the slither support, and in CI/CD pipeline tests the potential vulns and puts the result in the status bar.

