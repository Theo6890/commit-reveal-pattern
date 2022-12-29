# <h1 align="center"> Commit Reveal - Pattern Implementation </h1>

This repo implements the commit-reveal pattern. This pattern prevents frontrunning attack on betting type contract or similar. No one can see a clear input and submit the same transaction with the same parameters with a higher gas amount & price to to steel the original user's answer.

## Notes On Implementation

1. Not all tests are implemented as this is a minimal implementation to practically understand the commit-reveal pattern.
2. Same for some missing important features as: owner who can force a stage update or pause the game, update numbers of players, upgradeable contracts with diamonds, etc...
3. Important tests or features are commented using TODO and TEST tags.

## Intialise the repo

`yarn install & git submodule update --init --recursive && forge install`

## Launch tests

`forge test -vvv`
