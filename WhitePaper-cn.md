

**RWA 项目技术白皮书**  
*发行方：Future Flux*  
*版本：1.0*

---

## 目录
- [执行摘要](#执行摘要)
- [一、业务逻辑概述](#一业务逻辑概述)
- [二、技术架构](#二技术架构)
- [三、erc-3643-标准](#三erc-3643-标准)
- [四、合规去中心化交易所dex](#四合规去中心化交易所dex)
- [五、智能合约接口](#五智能合约接口)
- [六、治理风控与合规](#六治理风控与合规)
- [七、结论](#七结论)

---

## 执行摘要

Future Flux 的 RWA（现实世界资产）项目旨在将受监管的链下资产——包括债券、不动产、基金份额和应收账款等——以合规、安全、透明的方式引入区块链。该系统提供从资产上链、投资者合规认证到受限流通的全流程架构，确保现实资产能够以监管认可的方式实现数字化与流转。

项目采用 ERC-3643 标准，这是一种面向合规场景的代币规范，能够在保持 ERC-20 可组合性的同时，将投资者身份验证（KYC/AML）与监管可处置能力嵌入到代币的转账逻辑中。Future Flux 构建的模块化架构将法律结构、技术协议与金融流程有机结合，形成一个可持续、可审计、可扩展的 RWA 生态系统。

---

## 一、业务逻辑概述

### 目标
以合规方式将受监管的现实资产（如债券、不动产、基金份额、应收账款等）进行上链，实现安全的发行、赎回及二级市场流通。

### 端到端流程

**1. 资产端（链下）**  
- 资产筛选与尽职调查  
- 估值与评级  
- 法律结构化（SPV、信托或托管）  
- 生成链下法律凭证与权属证明（质押协议、认购协议、托管/信托协议）

**2. 合规模块**  
- 投资者 KYC/AML 验证  
- 按地区、资质、额度认证合格投资者  
- 结果写入链上身份注册表（Identity Registry）

**3. 发行端（一级市场）**  
- 基于 ERC-3643 发行代表受益权或份额的合规代币  
- 申购、赎回及分红/利息通过智能合约自动执行  
- 链下资金账户与链上事件联动，实现全流程闭环

**4. 二级流通（Secondary）**  
- 在合规 DEX（许可制 AMM 或 OTC）中进行受限交易  
- 可选地通过 Wrapped Token（wRWA）在公开 DEX 上交易，回兑需通过 KYC 验证

**关键约束：**  
- 仅白名单地址（KYC 通过）可持有与转让  
- 地域、额度、锁定期等限制  
- 监管事件触发冻结、强制转移或优先赎回

---

## 二、技术架构

### 系统概览

**链下模块：**
- **资产管理：** SPV、托管机构或信托结构  
- **KYC/AML 服务：** Sumsub、Trulioo 或自建合规系统  
- **资金流：** 银行托管、支付网关  
- **审计与风控：** 外部审计与报表系统

**链上模块（EVM 兼容）：**
- **ERC-3643 代币合约**  
- **身份注册表（Identity Registry）**  
- **合规模块（Compliance Module）**  
- **控制器（Controller）：** 权限冻结、强制转移  
- **一级市场合约（Primary Market）**  
- **合规 DEX/路由器（Permissioned DEX/Router）**  
- **预言机与储备证明模块（Oracle/Proof-of-Reserve）**

### 技术选型建议
- **区块链层：** 以太坊主网或合规友好 L2（Base、Arbitrum、zkEVM）；推荐主网发行、L2 交易以降低成本。  
- **钱包体系：** EOA + MPC 托管（机构）/ AA 钱包（提升用户体验）  
- **数据分析：** 事件总线 + 数据仓库（BigQuery/ClickHouse）+ 实时报表  
- **隐私保护：** PII 留存链下，仅在链上存储哈希标签与到期时间

---

## 三、ERC-3643 标准

### A. 概述
ERC-3643 是专为受监管资产设计的合规模型化代币标准，覆盖证券、基金份额、债券及其他 RWA。它在保留 ERC-20 兼容性的同时，将 KYC/AML 合规检查与监管可处置能力写入代币的核心逻辑。该标准最初由 Tokeny 提出（早期称为 T-REX），目标是实现“受监管的可转让性”：定义“谁可以在何种限制下持有或转让代币”。

### B. 关键角色
- **发行方（Issuer）：** 部署与管理代币，定义合规策略，执行企业行为（分红、赎回）  
- **合规管理员（Compliance Admin）：** 维护合规模块、更新名单/标签、处理冻结与强制转移  
- **身份服务商（KYC Provider）：** 完成链下 KYC/AML，向链上身份注册表写入结果  
- **投资者（Investor）：** 通过白名单校验后持有与转让代币  
- **托管人/受托人（Custodian/Trustee）：** 负责底层资产的法律与账务托管，与链上发行赎回对接

### C. 核心组件
1. **身份注册表（Identity Registry）：** 维护地址的合规状态（标签、到期、黑名单），PII 保持链下。  
2. **合规模块（Compliance Module）：** 在转账前强制校验地域、资格、额度、集中度、锁定期等，可通过 JSON/DSL 参数化配置。  
3. **可控性（Controllability）：** 提供冻结、强制转移、撤销等接口，满足司法/监管处置与私钥丢失场景。  
4. **ERC-20 兼容层：** 对外暴露 ERC-20 风格接口，便于钱包与协议集成，同时每笔转账均受合规模块约束。

### D. 生命周期
1. **注册与白名单：** 投资者完成链下 KYC，并写入身份注册表（标签+到期）。  
2. **发行与申购（Primary）：** 托管账户确认到款后，一级市场合约铸造或分配份额。  
3. **受限转让（二级）：** 每笔转让由合规模块审核，不合规即回滚。  
4. **企业行为：** 分红/利息、回购/赎回、拆分/合并等由发行方与一级市场合约执行。  
5. **合规处置：** 司法冻结、黑名单、强制转移（遗失/继承/法院裁定）。  
6. **失效与更新：** KYC 到期自动失效；需重新验证并刷新注册表。

### E. 对比表
| 维度 | ERC-20 | 简单白名单代币 | ERC-3643 |
|------|--------|----------------|-----------|
| 转账控制 | 无限制 | 静态地址白名单 | 基于身份标签+策略引擎 |
| 合规/到期 | 无 | 粗粒度、无到期 | 多标签、带有效期 |
| 司法/监管处置 | 不支持 | 可能支持冻结 | 原生支持冻结/强制/撤销 |
| 合规模型 | 无 | 静态名单 | 可配置策略（地域/额度/锁定期/集中度/时窗等） |
| 可组合性 | 高 | 中 | 高（保留 ERC-20 接口并前置合规） |

### F. 身份与凭证扩展（可选）
- 可与 VC/DID 集成：链下可验证凭证，链上写入标签指纹。  
- 可与 SBT（灵魂绑定凭证）搭配：作为合格投资者资格证明。  
- 可与 PoR/审计哈希联动：提升储备与审计透明度。

### G. 设计注意事项
- **最小化上链敏感信息：** 仅存标签、到期、指纹；PII 留在合规系统。  
- **策略可进化但可追溯：** 策略文件上链哈希与版本管理；每次升级需多签。  
- **旁路防护：** 在代币层同样强制 `beforeTransfer`，防止绕过路由直呼池或代币合约。  
- **跨链与桥接：** 目标链需同步注册表/策略，或采用锁定+重铸并重新验证。

---

## 四、合规去中心化交易所（DEX）

### 4.1 必要性
公开 DEX（如 Uniswap）无法拦截未 KYC 地址，易导致合规失败（因 3643 在转账层阻断）。RWA 场景要求仅允许合格地址参与撮合与做市，LP 也需白名单，并对交易对、价格发现、信息披露实施治理。

### 4.2 设计目标
- **白名单网关：** 所有 swap/add/remove 流动性先过 ComplianceRouter。  
- **可审计：** 撮合前后合规态势与身份快照可追踪。  
- **可组合：** 保留 AMM 可插拔（Uniswap V3/V4、Balancer、Curve），入口统一受控。  
- **可配置：** 不同 RWA 池应用不同规则（地域黑白名单、单笔限额、交易时段、价差限制等）。

### 4.3 架构与数据流（顺序图）
```
用户 (EOA/AA)
  → ComplianceRouter.swapExactTokensForTokens(...)
  → IdentityRegistry.check(address)
  → ComplianceModule.beforeTransfer()
  ← OK/REVERT
  → AMM.safeSwap()
  ← 输出代币
  → ComplianceModule.beforeTransfer(to)
  ← OK/REVERT
  ← 收到代币
```
**关键点：**  
- 禁止直接调用 AMM；用户必须通过 ComplianceRouter。  
- LP 操作（增/减流动性）同样走路由校验，LP 需在白名单。  
- 可选 Hook：若 AMM 支持 Hook/回调，可在池级别二次校验，双保险。

### 4.4 规则层（策略引擎）示例
```json
{
  "allowLabelsAnyOf": ["ACCREDITED_US", "EU_PROFESSIONAL"],
  "denyCountries": ["KP", "IR"],
  "maxPerTxUSD": 500000,
  "maxHoldingPct": 0.2,
  "poolOpenHoursUTC": "09:00-17:00",
  "cooldownSeconds": 300
}
```
由路由在链下缓存，链上存策略哈希锁定版本（防篡改 + 升级管理）。

### 4.5 Wrapped 方案（可选）
由合规托管方持有原始 3643 代币，发行 wRWA（普通 ERC-20）。  
- wRWA 可在公开 DEX 交易，提高可见度；  
- 回兑原生 3643 必须通过 KYC（桥合约双向兑付）；  
- 风险：增加托管与桥风险，需要 PoR 与提现 SLA。

---

## 五、智能合约接口

### 5.1 身份注册表（Identity Registry）
```solidity
interface IIdentityRegistry {
    struct Status { bytes32[] labels; uint64 kycExpiry; bool blacklisted; }
    function statusOf(address user) external view returns (Status memory);
    function isAllowed(address user, bytes32 requiredLabel) external view returns (bool);
    event StatusUpdated(address indexed user, bytes32[] labels, uint64 kycExpiry, bool blacklisted);
}
```

### 5.2 合规模块（Compliance Module）
```solidity
interface ICompliance {
    function beforeTransfer(address from, address to, uint256 amount, bytes calldata policy)
        external view returns (bool ok, bytes32 reason);
}
```

### 5.3 ERC-3643 控制接口
```solidity
interface IControllable {
    function freeze(address user) external;  // 多签/法院令
    function forcedTransfer(address from, address to, uint256 amount, bytes32 reason) external;
    event Frozen(address indexed user);
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount, bytes32 reason);
}
```

### 5.4 一级市场（Primary）
```solidity
interface IPrimary {
    function subscribe(uint256 amount, bytes calldata offchainReceipt) external;
    function redeem(uint256 shares, bytes calldata bankAccountRef) external;
    event Subscribed(address indexed user, uint256 amount, bytes offchain);
    event Redeemed(address indexed user, uint256 shares, bytes bankRef);
}
```
- **申购：** `offchainReceipt` 绑定链下来款凭证（支付网关/托管行回执哈希）。  
- **赎回：** `burn` 后生成链下付款指令，状态机在链上记录，链下签收回写。

### 5.5 合规路由器（Compliance Router）
```solidity
interface IComplianceRouter {
    function swapExactTokensForTokens(
        address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin,
        address to, bytes calldata poolPolicy
    ) external returns (uint256 amountOut);

    function addLiquidity(
        address tokenA, address tokenB, uint256 amtA, uint256 amtB,
        address to, bytes calldata poolPolicy
    ) external returns (uint256 lpTokens);
}
```

---

## 六、治理、风控与合规

### 6.1 法务与治理
- 多签（2/3 或 3/5）执行冻结/强制转移；  
- 冲突/争议处理流程与审计追踪（链上 Event + 链下工单号哈希）；  
- 投资者协议与信息披露页面（NAV、资产池余额、兑付进度）。

### 6.2 PoR / 报价 / NAV
- **储备证明（PoR）：** 托管机构定期签名 + 审计报告摘要上链（IPFS/Arweave 存证哈希）。  
- **价格源：** NAV/T+1 估值上链（预言机喂价）或 AMM TWAP 限制偏离。  
- **异常保护：** 当喂价异常/NAV 未更新，Router 进入限流/仅赎回模式。

### 6.3 安全
- 合约审计（≥2 家）、关键函数形式化验证（freeze/forcedTransfer/primary mint/burn）。  
- 访问控制：合规管理员、财务出纳、撮合运营分权。  
- 监控与可观测性：异常交易密度、黑名单命中、违反限额预警、KYC 到期提醒。

### 6.4 隐私与合规
- **PII 不上链；** 链上仅标签与过期时间/哈希指纹。  
- 遵循 GDPR/PDPA：用户“被遗忘权”在链下处理，链上可用标签过期与匿名化。

---

## 七、结论

Future Flux 提供了一套完整的 RWA 上链技术框架，融合合规代币标准、模块化合规架构与受控流动性环境，实现了合规与 DeFi 的桥接。该系统既提升资产透明度与可验证性，也为机构级投资者参与去中心化金融提供安全入口，为下一代受监管 DeFi 奠定基础。
