# 📈 Fair Launch Protocol: Mathematical Bonding Curve

A decentralized, autonomous token launchpad protocol inspired by the "fair launch" model. This protocol leverages a **Quadratic Bonding Curve** to ensure continuous liquidity, organic price discovery, and a bot-resistant graduation phase. 

Designed for the **Moca Network**, the system automates the transition from a bonding curve to a secondary market (DEX) once a specific funding goal is met.

---

## 🏗 System Architecture

The protocol is split into two primary layers to maximize security and modularity:

| Layer | Contract | Responsibility |
|:--- |:----------- |:-------------- |
| **Factory** | `TokenLaunchFactory.sol` | Deployer and registry. Manages the deployment of unique curve instances for every new token. |
| **Engine** | `FairLaunchCurve.sol` | The mathematical core. Handles all buy/sell logic, integral math for pricing, and the final graduation event. |



---

## 🧮 The Mathematical Model

Unlike basic linear models, this protocol implements a **Quadratic Bonding Curve**. The price increases as a function of the supply squared, rewarding early adopters while preventing late-stage price stagnation.

### 1. Price Function
The marginal price $P$ for a supply $s$ is defined by:
$$P(s) = \frac{2 \cdot \text{TargetMoca} \cdot s}{\text{InitialTokens}^2}$$

### 2. The Integral (Cost to Buy)
To ensure fairness for large transactions, the protocol calculates the **Area Under the Curve** (the integral) rather than using the spot price. This prevents price manipulation within a single block.



The amount of tokens received ($\Delta t$) for a given MOCA input ($\Delta m$) is:
$$\Delta t = \sqrt{t_1^2 + \frac{\Delta m \cdot T_0^2}{\text{TargetMoca}}} - t_1$$

Where:
* $T_0$ = Initial token supply in the curve.
* $t_1$ = Current tokens already sold.
* $\Delta m$ = MOCA amount sent to the contract.

---

## 💎 Key Features

* **Fair Launch Mechanics:** 100% of tokens are placed in the curve. No team allocation, no pre-sale, no "insider" advantage.
* **Automated Graduation:** Once the curve collects **10 MOCA** (target goal), the sale is finalized. The collected liquidity is automatically transferred to a **Liquidity Vault**.
* **Slippage Protection:** Built-in slippage parameters for every `buy` and `sell` transaction.
* **Native MOCA Integration:** Handles native MOCA by auto-wrapping into **WMOCA** for consistent internal accounting.
* **Oracle Lifecycle Management:** High-security "Start" and "Pause" controls managed by a dedicated Oracle wallet.

---

## 🚀 Execution Flow

### 1. Deployment
The Factory deploys a new `FairLaunchCurve`. The total supply is deposited into this contract, creating the initial reserve.

### 2. Trading Phase
Users interact with the `buy()` and `sell()` functions. As tokens are purchased, the contract stores the native MOCA in the reserve, and the price moves along the quadratic curve.



### 3. Graduation
When the **Graduation Threshold** (default 90%) is reached:
1.  Trading is paused via the `finalized` flag.
2.  Collected MOCA is moved to the `vaultReceiver` address.
3.  The token is ready to be paired with the graduated MOCA on a secondary DEX.

---

## 🛠 Setup & Deployment

### Compile
```bash
npx hardhat compile
```
### test
```bash
npx hardhat test
```
## 📜 License
Released under the MIT License.