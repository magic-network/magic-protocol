# Magic Protocol Overview
The Magic Network is creating an open market for wireless internet access for consumers and connected devices. With Magic users and devices can seamlessly switch from cellular connections to wifi to reduce data costs while remaining on private and secure connections.

Magic includes two cryptographic tokens: **MGC** are a governance token that reward participation in the network and receive royalties for paid transactions on the network, and **Magic Credits** are a consumer-facing utility token that users purchase at a constant rate of 100 Magic Credits per $1 USD. MGC, Magic Credits, and the smart contracts governing them are an application-specific blockchain built on the Cosmos Network.

## Network Actors
There are four kinds of actors on the Magic network: **Consumers**, **Providers**, **Validators**, and **Delegators**. Consumers are users who connect to the internet via Magic. They may be humans connecting a mobile phone or a laptop, or autonomous devices connecting automatically. Providers make internet access available to Consumers on the network. They may be as small as a single wifi hotspot in a coffee shop or as large as a cellular carrier accepting payment over the Magic network. Validators confirm transactions on the network to ensure that access is being provided as agreed, and they validate new blocks in Magic’s distributed ledger. Delegators elect the pool of Validators by staking MGC with them.

![Network Actors Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)

Note that Providers on the Magic network may themselves be Consumers receiving their upstream connectivity via Magic as well. In the simplest implementation, such a Provider might be as small as a Raspberry Pi extending the range of an existing Magic wifi network.

![Two-Hop Network Actors Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)

Providers set the price they want to charge for internet access, which may be zero. We anticipate that many Providers may provide access without charging, the way that many places offer free wifi service today. The Magic network treats them the same as any other Provider.

## Tokens and Payment

### MGC Governance Tokens

#### Staking and Validation
Operation of the Magic network is governed by MGC. Validators must stake MGC to participate in validating transactions and new blocks on the Magic blockchain. MGC holders may also be Delegators, and stake their MGC alongside specific Validators without necessarily operating their own Validator node. In exchange, new MGC are minted as those new blocks are created, and the inflation proceeds are distributed to the Validators, and the Delegators staking with them. Validators that misbehave or don’t maintain uptime have their MGC stakes slashed, and those of Delegators who stake with them.

The rate of inflation varies inversely with the participation rate to encourage all MGC holders to play an active role in regulating the network. MGC holders that do not stake their tokens will see the relative share of the network they represent fall over time as all inflation accrues to active participants, while holders who stake consistently and don’t have those stakes slashed will see their relative share remain stable or even rise over time.

#### Royalties
MGC entitle their holders to a **MGC Royalties**, paid for all transactions on the Magic network. As Magic Credits are spent, the network mints new Magic Credits equal to a small percentage of the total transaction volume, for example 1%, and distribute them evenly to MGC holders. The mechanics are described in Calculating MGC Royalties, below, and the specific royalty rate varies over time, as described in The Path to Decentralization, below.

The best approximation for the value of a marketplace is a total transaction volume that takes place across it. Entitling MGC holders to a share of that transaction volume makes the value of MGC track the value of the network as a whole. That rewards MGC holders for participating and incentivizes them to take actions that grow the value of the network.

#### Governance
At launch governance of the Magic network is controlled by the development team, who can choose to deploy updates or change the value of parameters on the network to maximize growth and adoption. Over time, we intend to transition control over those operations to a DAO operated by MGC holders, as described in The Path to Decentralization, below.

#### Regulation and Distribution
At launch, we expect regulators, most notably the US Securities and Exchange Commission, to treat MGC as securities. They will initially be held entirely by Hologram and the Magic core development team. Some portion may be sold to accredited investors to raise money to fund development of the Magic network.

We then expect to make some portion available to early adopters in the general public via Regulation Crowdfunding. We anticipate distributing MGC in this way not just to purchasers, but to qualified participants who support the network in other ways, for example by learning about the Magic network, setting up Provider nodes in a new area, or signing up to be a Validator.

Long-term we intend to file under the SEC’s Regulation A to make access to MGC more widely available. The Regulation A process is long and expensive, so we want to grow the network organically before undertaking it.

In the very long term we hope to have the Magic network certified by regulators as fully decentralized. That would make MGC no longer count as securities (as there is no “common enterprise” in a fully distributed network), removing any restrictions on the sale of MGC. That plan is discussed in The Path to Decentralization, below.

### Magic Credits Utility Tokens
Transactions between Providers and Consumers are conducted in Magic Credits, a second cryptographic token on the Magic network. Where MGC track the value of the network and may increase in value over time, we introduce a second token that does not increase in value, making it suitable for sale to the general public as a pure utility token.

#### Minting and Purchasing
Magic Credits are a medium of exchange and thus need to have a reasonably stable value. Wild swings in the value of Magic Credits would translate into wild swings in the real price of internet access denominated in Magic Credits. Unpredictability would make Magic Credits unattractive to users and providers alike; because of this we stabilize the value of Magic Credits by selling them to users at a constant price (100MGC per $1USD). We hold the proceeds of that sale in a smart contract called the **Reserve**. The Reserve mints new Magic Credits and gives them to the paying user. The Reserve tracks the total number of Magic Credits in existence; there is no other source of Magic Credits.
```
buy_credits(purchaser, atoms)
  ...
  purchaser.atoms -= atoms
  reserve += atoms
  dollars = atoms + get_atom_usd_exchange_rate()
  credits = dollars * 100
  total_credits += credits
  purchaser.credits += credits
  ...
```
The Reserve takes payment in Atoms, the common currency of the Cosmos network. Atoms are readily available for purchase on exchanges, and can also be obtained by bonding other cryptocurrencies, including Ethereum and Bitcoin. Accepting payment in Atoms gives the Magic network maximum interoperability with existing cryptocurrency ecosystems. In addition to interoperability at the protocol layer, the Magic team will make third-party experiences to allow users to transact directly in dollars to bootstrap growth, and expects that others will emerge in the ecosystem over time.

Because Magic Credits are sold in unlimited quantities at a fixed price, they do not appreciate and there is no incentive to hold them. For ordinary users, they are a pure utility token; they do not trade on exchanges and may only be spent in exchange for internet access from provider nodes on the Magic network. Providers who receive Magic Credits can redeem them as described in Redemption and Burning, below.

#### Redemption and Burning
For Magic to function as a marketplace Providers need to be able to receive payment. We treat the Magic Credits they receive from Consumers as equal claims on the Atoms held by the Reserve, and allow qualified Providers to **redeem** their Magic Credits and receive Atoms.

Magic Credits can only be transferred to Providers on the Magic network as part of a smart contract for internet service. Providers can spend those tokens on their own internet access or hold on to them. Providers may optionally complete a Magic KYC/AML process to qualify to receive redemptions. Providers certified to receive redemptions are placed on a whitelist in the Reserve. Providers on the whitelist can redeem tokens for Atoms, with each token representing an equal portion of the ETH held in the Reserve. Magic Credits redeemed in this way are burned.

```
redeem_credits(redeemer, credits)
  ...
  if redeemer not in whitelist
    return
  atoms = reserve * total_tokens / credits
  redeemer.credits -= credits
  total_tokens -= credits
  reserve -= atoms
  redeemer.atoms += atoms
...
```
Note that this means Providers are exposed to volatility in the price of Atoms. While consumers can always buy 100 Magic Credits for the same price in dollars, the amount of Atoms they deposit in the Reserve will vary inversely with the price of Atoms. That will change the number amount of Atoms each token may be redeemed for. And if the price of Atoms changes in between a consumer’s purchase and a provider’s redemption, the Atoms that are redeemed may be worth more or less than $1. Providers would prefer a stable exchange rate, to make them better able to predict the value of the Magic Credits payments they receive, and to allow them  to make investment in capital goods like routers and small cell equipment that is required to provide internet access.

That stability comes in several ways. First, providers are the more sophisticated party in transactions on the Magic Network and are better able to bear Atom volatility or hedge it away. They also independently set the price in Magic Credits they charge per byte of data and can adjust those prices to charge a constant dollar (or other local currency) amount per byte.

Second, we expect Magic Credits will transit quickly through the Magic ecosystem from users to providers to be redeemed at the Reserve. They can’t appreciate in value and can only be spent for access, so Consumers have no reason to hold them long-term. Quick transit through the ecosystem should limit providers’ exposure to the price volatility of Atoms.

Finally, the Reserve may optionally further limit volatility by automatically exchanging some or all of the Atoms deposited with it for DAI, other stablecoins, or a basket of assets. Active hedging by the Reserve could be done at the direction of the Magic team or eventually as directed by a DAO controlled by MGC holders, as described in The Path to Decentralization, below.

#### Regulation and Distribution
Providers can only get paid for providing internet access if users can buy Magic Credits to pay them with, so any restrictions on users’ ability to buy Credits harms network growth. Users need to be able to buy Magic Credits without being accredited investors, and preferably without an extensive KYC/AML process that would harm conversion rates in user onboarding. Magic’s dual token design is closely modeled on that of Pocketful of Quarters, which obtained a no-action letter from the SEC that their consumer-facing utility token is not a security. Because Magic Credits do not increase in value and can only be used on the Magic network to obtain internet access, we expect them to be treated the same way by regulators.

### Calculating MGC Royalties
MGC Royalties are governed by a smart contract called the **Royalty Contract**. Whenever a transaction is completed on the Magic network, the Reserve creates new Magic Credits equal to 1% (for example) of the transaction’s value and deposits them in the Royalty Contract. The Royalty Contract divides the proceeds evenly among the MGC. Creating royalties by minting new tokens reduces the number of Atoms existing tokens can be redeemed for at the Reserve. Because the dilution affects all tokens and not just tokens used in transactions, it encourages Providers to redeem promptly. That reduces the time that the Reserve holds the Atoms used to purchase Magic Credits, reducing the exposure of Magic Credits to variations in the price of Atoms.
```
transfer(sender, recipient, credits)
  ...
  sender.tokens -= credits
  recipient.tokens += credits
  royalty_contract.credits += 0.01 * credits
  ...
```

MGC holders can direct the Royalty Contract to transfer any balance associated with their MGC to a Provider account for redemption. Implementation of this process is modeled on Pocketful of Quarters’s Q2 tokens: https://github.com/weiks/quarter-sol/blob/master/contracts/Q2.sol

The royalty rate is set high enough to make MGC attractive to hold for early adopters and Validators, but low enough to not discourage Providers from providing access that Consumers pay for in Magic Credits, with the aim of maximizing the long-term growth of the network, and therefore long-term value of MGC. We expect that the optimal rate will vary over time, and make it adjustable as a parameter on the Royalty Contract. At launch, the royalty rate will be set by the Magic team, with the long-term intention of moving it to be controlled by a DAO managed by MGC holders, as described in The Path to Decentralization, below.

## Incentives for Network Expansion
Magic is a two-sided marketplace with classic network effects: each new participant in the marketplace increases that value it provides to all existing participants. Providers can only capture the value they create for purchasers (since users won’t pay for more than that), missing out on the value they create for other users, including free users, by expanding coverage. Academic estimates for the magnitude of this effect are that expanding coverage can create three times as much value for network participants as providers can capture is usage fees (https://academic.oup.com/restud/article/86/3/1033/5061115?guestAccessKey=8628aed3-426d-4fc6-af39-bd5561c493a3). In the limit case, the first provider in a new market won’t have any users at all, and no prospects for receiving direct payment until the community of paying users grows. All together, that means the long-run value to Magic of providers setting up nodes in new markets will be higher than those providers can capture through selling access. To maximize the growth of the network, we need to provide special incentives to set up the first nodes in a new area, which we call **pioneer nodes**.

As discussed above in the Regulation and Distribution section of MGC Governance tokens, we plan to reward early adopters directly with MGC, which can be airdropped manually as part of a Regulation Crowdfunding event. Over the long run, however, we want the structure of those rewards built into the protocol.

Over the long run, the best measure of the value of the Magic network is the total amount users spend on connectivity. We tie rewards to producers to that long-term value through two mechanisms. First, while most of the balance of a payment for connectivity on the Magic network goes to the provider, a portion (e.g. 5%) of every transaction is reserved as a **Network Access Fee**. This operates like a sales tax (i.e. VAT) with incidence on the provider (unlike American sales taxes that are added on top of the list price). As with exposure to Atom volatility, providers are the more sophisticated party, and can compensate by setting a higher MGC price per byte. Funding the Network Access Fee as a tax instead of with inflation makes it Sybil resistant. Even if a single person controls the user, provider and any accounts that would receive network access fees, they can only pay themselves with their own tokens.

For each Magic client, the protocol maintains a **connection history list** of 5 unique nodes, in the usual case the last five nodes a client connected to. Whenever a client pays for access, the Network Access Fee for that transaction is split evenly between the nodes in their connection history list. This rewards Providers, even Providers that charge zero Magic Credits, that usefully expand network coverage to paying users. It protects against fake providers that purport to offer coverage in an area their devices don’t actually cover, by only rewarding nodes actually in the connection history of paying clients. Fake nodes spoofing their location won’t show up in the connection history of actual clients, so we can use the simple consensus of paying clients and receiving providers as proof of location.
```
transfer(sender, recipient, credits)
  ...
  sender.credits -= credits
  recipient.credits += 0.95 * credits
  for node in connection_history:
    node.credits += 0.01 * credits
  ...
```

We reward nodes that **pioneer** service in a new geography by giving them priority placement in the connection history lists of clients that connect to them. This rewards nodes that drive early adoption with greater network access fees, and ties the magnitude of that reward to the total value of the market segment they started adoption in. We identify pioneer nodes via an on-chain data structure that keeps a five-node **leaderboard** for every geography on Earth.
```
 record_connection(node)
  ...
  if node in connection_history
    return
  leaderboard = leaderboard_at(lan, lon)
  if node in leaderboard
    connection_history.push(node)
    return
  for index, history_node in connection_history
    if history_node not in leaderboard
      connection_history.insert_at(index, node)
      return
  ...
```
Nodes are ranked on the leaderboard by our best measure of their long-term contribution to the value of the network: the all-time sum of network access fees they have collected. This deliberately creates a momentum effect: nodes that are the first to collect network access fees in a new geography receive priority on future network access fee rewards. That momentum lets early pioneers continue to be recognized for their early contributions even as they comprise a smaller and smaller share of growing network traffic.
```
 claim_leaderboard(node)
  ...
  leaderboard = leaderboard_at(node.lat, node.lon)
  if node in leaderboard
    return
  for i=0; i<leaderboard.length; i++
    if node.total_access_fees > leaderboard.get(i).total_access_fees
      leaderboard.insert_at(i, node)
      return
  ...
```
Leaderboards for each geography are stored as entries in a hash table where the key is the latitude and longitude of the region at a precision of tenths of a degree. That creates a rough correspondence of one leaderboard per metro area (https://xkcd.com/2170/), with the advantages of being very cheap computationally and relatively easy for lay users to understand.
```
 leaderboard_at(lat, lon)
  ...
  lat_str = (int) (lat * 10) + lat > 0 ? 'N' : 'S'
  lon_str = (int) (lon * 10) + lon > 0 ? 'E' : 'W'
  key = lat_str + lon_str
  return leaderboard[key]
  ...
```
This will result in some metro areas being divided into two or more leaderboards, but that doesn’t disrupt the overall incentive effect, and may be appropriate for larger metros, like the five boroughs of New York City.

Taken together, this set of functions provide the potential for a large upside (up to 1% of all future paid network traffic in the leaderboard geography) for early adopters who expand coverage into a new useful geography and broadcast continuously.

## Validation
Magic implements a fixed interface for contracting for payment in exchange for connectivity so new nodes and users can join the network **permissionlessly**. To make contracting possible in a trustless environment, the network relies on Validators to fulfil two functions: verifying individual transactions on the Network were completed honestly, and maintaining the distributed ledger of all balances and transactions across the network.

###Proof of Transport
When a Consumer and Provider transact on the Magic Network, a Validator ensures the promised connectivity is actually provided and the promised payment is actually made. The validation relies on a cryptographic function we call **Proof of Transport**.

Consumers choose a Validator at the time they open a connection. That Validator becomes the exit node for the Consumer’s traffic. Network data is end-to-end encrypted between the user’s client and the chosen Validator, and the Validator settles payment to the Provider. This makes them play a role like the [home network](https://en.wikipedia.org/wiki/Network_switching_subsystem#Home_location_register_(HLR)) for existing mobile phone networks.

![Proof of Transport Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)

A gateway must deliver a packet between the client and the verifier, who each co-sign micropayments for each successful micro-delivery of data, in order to for the payment to succeed. Zero knowledge about the plaintext (or even the full ciphertext) is needed by the Magic network or its smart contract in order to correctly enforce the delivery/integrity assurance constraint prior to payment. Once Proof of Transport is complete, payment is sent from the user to the provider, less any Network Access Fees as described above.

### Block Validation
The Magic Network is built using the Cosmos SDK, which creates a private, application-specific blockchain to power the network. New blocks in the chain are created and verified using the Tendermint distributed proof-of-stake protocol. Validators work together to agree on new blocks, and nodes that try to cheat or fail to keep up are punished by the network.

Block Validation is done by the Validators that have the most MGC Staked with them, as described below. The maximum number of Validators in the Block Validation pool is set to maximize network throughput, and may vary over time, though the Cosmos team suggests 1000 Validators as a rule of thumb. At launch, the specific maximum will be adjusted by the Magic team to maximize network growth, with the long-term intention to transition it to a DAO managed by MGC holders as described in The Path to Decentralization, below.

### Staking and Inflation Rewards
Validators may **stake** some amount of MGC to demonstrate their commitment to the network. Delegators also stake their tokens alongside Validators, signaling their confidence in those Validators’ reliability. MGC that are staked are locked up for a fixed period of time and may not be transferred or otherwise used while staked. To encourage participation, at fixed intervals new MGC are minted and distributed to the holders of MGC that are staked successfully. We call these distributions **inflation rewards**.

The amount of inflation rewards created varies over time to target a constant, high rate of staking on the network. We want to encourage MGC holders to take an active role in governing the network by voting on which validators are trustworthy and high-performance. When the participation rate falls below the target, the rate of inflation increases; when the participation rate rises above the target, the rate of inflation falls. We start with a target participation rate of 90%, which is a value that can be changed early on by the Magic team to maximize network growth, with control eventually passing to a DAO controlled by MGC holders, as described in The Path to Decentralization, below. We expect the optimal rate of inflation to be approximately 2%.

Inflation rewards are distributed evenly among all MGC that are staked successfully. For MGC staked with Validators, the stake is successful if the Validator is chosen to go into the Validator pool, because it was one of the validators with the most MGC staked on it. This creates an incentive for MGC holders to coalesce around a set of useful validators; they won’t receive inflation rewards for intentionally staking with an obscure Validator that they’re confident won’t be chosen. Because rewards are distributed evenly, MGC holders that participate successfully in the network will in the worst case never see their share of MGC decline. In practice not all holders will always stake or always stake successfully, so MGC holders who do will see their total share of outstanding MGC rise over time. There are a number of services that offer to manage staking on behalf of cryptocurrency holders, and we intend for the Magic network to be fully compatible with those services.

Where pro-social participation in the network is encouraged with inflation rewards, activity that harms the network is discouraged by burning some fraction of the staked MGC. These penalties are called **slashing**. MGC staked with Validators are slashed if those Validators vote to validate a new block that is not accepted by the Validator pool, or if they do not maintain uptime throughout the validation period. We start with a slashing penalty of 20% of the MGC staked, which is a value that can be changed early on by the Magic team to maximize network growth, with control eventually passing to a DAO controlled by MGC holders, as described in The Path to Decentralization, below.

## Privacy
Traffic on the Magic Network is encrypted end-to-end to the Validator node, so Consumers don’t have to worry about Providers being able to snoop on their traffic. But you do have to worry about the Validators, especially in a trustless system. Staking and slashing can be used to ensure that Validators compute new blocks honestly and that they don’t have downtime, because those behaviors are observable, but there is no way to verify that Validators aren’t snooping on Consumers’ internet traffic.

The simplest privacy solution for Consumers is to use an existing VPN service they trust. The Magic Network is designed to be an open, pluggable ecosystem, and be compatible with present-day best practices. Any Validator node would then only see already-encrypted traffic the Consumer was sending to their VPN provider. In addition, we will provide a batteries-included VPN at launch that takes payment in Magic Credits, either implementing ourselves or partnering with a trusted provider. Magic client software will use this service by default. We hope additional providers will emerge or partner with us to offer seamless VPN service that takes payment in MGC, and we will encourage their development. Long-term we hope a full-decentralized VPN service like [Orchid](https://www.orchid.com/) is successful, but implementing one ourselves is beyond the scope of our project.

Alternately, users can operate their own Validator node, they way they might run a private VPN. That eliminates any need to trust a VPN provider not to secretly monitor connection data, which would travel encrypted from the Consumer to a Validator node the user also owns. A user-operated Validator node would not need to compete for block validation rewards, opting to perform only traffic validation to reduce the computing resources required to operate it. At launch we expect such nodes to only be operated by especially technical or enthusiastic early adopters, but over time the Magic team intends to make doing so a push-button experience by producing distributions of the validator node software that can easily be installed on common execution environments like AWS, Heroku, or on a Raspberry Pi.

## Scalability
Early development prototypes of Magic were built on the Ethereum network and devoted significant engineering resources to increasing the number of transactions per second it could achieve on the Ethereum blockchain. In the meantime, the blockchain ecosystem has matured. More recent versions are developed with the Cosmos SDK, which uses the Tendermint proof-of-stake consensus algorithm to achieve thousands of transactions per second out of the box.

In the happy event that the Magic network starts to push up against those limits, the Magic development team will resume investigating sharding, probabilistic micropayments, Micro Raiden-inspired payment channels to increase total network throughput.
Network Diagrams

![Purchase and Minting Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)
Fig 1. Uma buys 200 MGC from the Reserve in exchange for $2 of ETH (e.g. 0.01 ETH). Reserve goes from 100 ETH to 100.01, total MGC in circulation goes from 2000000 to 2000200

![Connection History Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)
Fig 2. Uma connects to Provider nodes operated by Frank, Louis (who is on the Leaderboard), Francesca, Finnegan, Fiona, Fred, and Fatima, all of whom charge zero Magic Credits.

![Payment And Network Access Fee Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)
Fig. 3. Uma buys 100 MGC of connectivity from Priya. Priya gets 95 MGC, Fatima, Fred, Fiona, Finnegan, and Louis (not Francesca!) get 1MGC each. 5MGC are minted and deposited in the Magic Big Token Contract.

![Inflation Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)
Fig. 4. Priya redeems 95 MGC and gets 95/2000200 * 100.01 ETH

## Resistance to Common Attacks

### Sybil Attacks
We make Magic resistant to Sybil attacks by ensuring there are no exchanges on the network that produce more tokens than they cost. This is why Network Access Fee is a tax whose incidence falls on the Provider; no more tokens are sent to provider nodes than were spent by users. If an attacker owns the User, Provider, and all the nodes in the connection history, they can capture their own full payment, but no inflation, which only goes to MGC holders. The transactions in the attack itself caused a little inflation, decreasing the value of the tokens the attacker just paid themself with.

![Sybil Attack Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)
<This same chart, but all the colors except the MBTC are the same and the all the letters other than MBTC are “A.” Then a Total at the bottom showing that A is at +0 Magic Credits, and MBTC is at +5>

### Location Spoofing
We allow Users and Providers to prove the location of a transaction through simple consensus. If both agree on where the connection happened, the Magic networks believes them. This does allow an attacker to falsely attribute transactions where he pays himself to a location he’s not actually providing service in. We call this kind of attack location spoofing.

![Location Spoofing Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)
<This same chart, but with F2 in place of L in the bottom left and in U’s connection history. Add a Leaderboard pop-out with the 5 places filled by Attacker 1, Attacker 2… etc>

As with Sybil attacks, we make Magic resistant to location spoofing by ensuring that any rewards an attacker could receive are worth less than it costs to conduct the attack. In this case, the only value tied to a transaction’s location is earning a spot on the Leaderboard. Being on the Leaderboard is only valuable if you show up in the actual connection history of users buying connectivity. If you’re spoofing your location to put yourself on the leaderboard, you won’t be in the connection histories of actual users spending money there, and you won’t get any rewards. Since running fake transactions has real costs in gas and in inflation, and there’s no economic benefit, rational actors won’t attempt location spoofing. As the network grows, the volume of real transactions grows with it and the cost of a location spoofing attack rises, while still yielding no economic benefit. In the long run we expect no significant location spoofing on the network.

## The Path to Decentralization
At launch, Magic will still be a relatively centralized system. The Magic development team will retain the ability to make updates to key parts of the protocol to ensure the network is functioning as intended and to maximize its growth rate.

Over time, we will transition it to be more and more decentralized, until it is autonomously operated by stakeholders on the network. Having a concrete plan for eventual decentralization is important for user adoption, as a decentralized network gives users stronger guarantees it won’t become exploitative. Pushing towards full decentralization has several other benefits as well. When the network is fully decentralized to satisfaction of securities regulators, Magic Big Tokens will cease to be securities. SEC guidance explicitly contemplates this transformation, which they call **mutability**. That means MGC would be free to trade on cryptocurrency exchanges, providing liquidity to early purchasers and making them available to community members who couldn’t participate in a crowdsale. It will also mean we can relax the restriction that only providers that have been through a centralized KYC/AML process can receive redemptions from the Reserve. That will make the onboarding process for new providers easier, allowing the network to grow faster.

In particular, there are several parameters of the Magic smart contracts that can be fine-tuned to maximize the network’s growth rate, and that make natural candidates for eventual distributed governance via a DAO. We call these parameters **knobs**. Key knobs include:
- The number of nodes in the connection history that receive Network Access Fee payments
- How long being on the Leaderboard keeps a node in connection histories
- The rate of inflation awarded to Magic Big Tokens as royalties
- The rate of inflation awarded to Validator nodes and MGC holders who stake with them
- The basket of assets the Reserve holds, and any algorithmic trading rules it has for diversifying across stablecoins or hedging in other ways
Over time we will transition setting the values of these knobs to a DAO with MGC holders voting on proposed policies.
## Roadmap and Timeline

![Roadmap Diagram](https://s3.us-east-2.amazonaws.com/hologram-static/magic/marketing/bao_highres_1_comp.png)

## Alternate Models
We believe that pairing the governance token MGC with a new consumer utility token Magic Credits represents the best path forward, but we want to explicitly consider a few alternate models opted not to pursue.

### Build on the Ethereum Network
Early prototype versions of the Magic Network were built on Ethereum, the largest and most mature smart contracts platform at the time we started. We were optimistic that performance improvements on the Ethereum roadmap would allow a network built on top of Ethereum to scale to our anticipated transaction volume

### Use a Third-Party Stablecoin for Payments
We could potentially adopt a third-party stablecoin to use in place of Magic Credits. In theory, doing so could reduce technical and product risk and make us more sure that our coin would have a stable value as intended. We would retain the ability to issue MGC that track the overall value of the network by levying a transaction fee, but would not have to hold Atom reserves to back our consumer token, or deal with KYC/AML controls on providers for redemptions.

The most obvious drawback of using a third-party stablecoin for exchanges is losing the ability to program how the tokens behave. In particular, while Network Access Fees are designed to operate like a sales tax, MGC Royalties are currently created via inflation. That lets us spread the cost of creating them across all tokens in circulation, not just those that are spent, decreasing the degree to which the fees discourage token velocity. Using a third-party token takes away that flexibility.

A larger concern is, it isn’t clear that there is an existing third-party stablecoin on the market that would actually reduce product risk. The largest stablecoin is DAI, a levered asset that has already struggled to maintain its dollar peg. Using it adds a new long tail currency risk, and one that the Magic team can’t control or mitigate. Those risks would be mitigated by using Libra, which is backed by a basket of regular currencies held in reserve. But Libra are governed by Facebook, one of the least trusted brands in the world by our potential early adopter base that’s excited by a decentralized internet. Even if using a third-party stablecoin looked promising in theory, there doesn’t seem to be an actual existing stablecoin ready for use today that would be clearly superior to creating our own.

Finally, as described above we can mitigate Atom volatility risk by having the Reserve hold some or all of its cryptocurrency in DAI, Libra, or any other stablecoins that can be readily exchanged for Atoms. The Reserve can even hold a basket of competing cryptocurrency assets to spread risk and volatility across them. That appears to give us all the price stability we need, without sacrificing any degrees of freedom in our protocol design or taking on any new platform risk.

## Acknowledgements
We’ve significantly altered our approach over a year and a half of working on prototypes for the Magic network, and we wouldn’t have the robust solutions we have today without inspiration from other projects in the space. In particular, the Magic team would like to thank: Livepeer for inspiring our participation model for validator nodes, Althea for inspiring us to use Cosmos for scalable microtransactions, and Pocketful of Quarters for inspiring us to use a two-token model for consumer payments.
