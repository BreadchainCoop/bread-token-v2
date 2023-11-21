# Bread Token V2

The Breadchain Stablecoin is an experiment in **lossless donations** or **crowdstaking** for the Breadchain Collective. The idea is that users mint BREAD which is pegged 1:1 with DAI however under the hood the DAI earns yield which is captured not by the token holders but the Breadchain Collective's public goods funding stream. Thus users who hold and transact with BREAD are actually continually donating to the Breadchain Collective's public goods funding stream.

The BREAD token v1 was deployed on Polygon PoS and the underlying yield generation source was Aave's lending market. Switching to Gnosis Chain and using sDAI as the underlying yield source has major benefits:

- Since xDAI is native gas token on Gnosis Chain, users don't need both the gas token and DAI in order to onboard.
- Since sDAI is the native yield source for xDAI, it's less variable yield and carries less risk than the Aave market. Yields are also generally much higher!

## Setup

bash```clone```

bash```forge install```

bash```forge compile```

## Test

bash```forge test --fork-url <YOUR QUICKNODE GNOSIS CHAIN ENDPOINT> --fork-block-number 31060200 -vv```

create an account [here](https://www.quicknode.com/) and get a gnosis chain endpoint on the free tier to get running the test suite.
