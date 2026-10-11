# 0149 · UI 验收与打磨（v3 第一轮）：MEME v2 列表与项目页、签名出口、挖矿三页、钱包算力抽屉（S151-mobile）

## Status

Accepted 2026-10-11。主代理下单（S151-mobile），基线 `integration/v2` 91ab8b0，分支 `feat/S151-ui-polish`。
依据：0122 / 0123（视觉二期与收尾的页面语法）、0139 / 0140 / 0145 / 0146、`docs/product-decisions.md` 0120–0123；
主代理验收记录 `LOOP/docs/acceptance/2026-10-11-s142-emulator.md` 观察项 3。dev 后端 loop-api 9b6e1d5（真实测试网）。
不新增依赖、`pubspec.lock` 不变、路由清单不变、token 标尺与圆角不变、无新字体、无动效、状态机 / 数据层 / 交易逻辑不变。

## Context

按 design-polish 流程逐屏验收：先以钱包页与聊天列表定基调（纯黑底、OKX 行无卡无线、Lime 只给主动作 / 进度 / 选中 /
可交易态、深灰实心胶囊筛选、键值表 11 px 灰标签列 + Chalk 值列、每块数据有来源行），在 emulator-5554（qa-privy2）上
截 before / after，每屏改完由独立评审（`claude -p --model opus`，只读截图，不操作设备）按本 App 的页面语法打分，
每屏最多三轮。证据 `LOOP/docs/evidence/2026-10-11-s151-ui-polish/`，记录 `LOOP/docs/acceptance/2026-10-11-s151-ui-polish.md`。

## Decision

每条一个提交（提交信息写屏名与问题）。

### 共用件（默认值不变，旧调用点行为不变）

- `LoopKeyValue` 加 `labelFlex` / `valueFlex` / `valueAlign`（默认 1 / 1 / right）。签名出口 `LoopSignSheet` 的事实表用
  2 : 3 与起始对齐：「先授权 2,000 $S13776DF 给官方池路由」一行放下，换行时第二行与第一行同起点（S142 观察项 3）。
- `LoopSkeleton(priceRow)` 占位行换成加载后的 OKX 行形：去掉每行底部发丝线、右侧两行、尾部 96 × 44 块
  （`loopSkeletonPillSize`）。影响 MEME「v2 发射 / 经典 / 已毕业」、行情、发射台所有价格列表的加载态。
- `LoopSegBar` 加 `padding`（默认仍是页边距 16 + 底 14）。三个交易面板（外盘、内盘、MEME 交易抽屉）本身已在页边距上，
  传无水平内边距，「买入 / 卖出」不再比其他控件多缩进 16。
- `LoopPowerHint`：句子在上、数字在下（不再一行内联，避免「当前算 / 力公式」断在词中间）；有 `onTap` 时尾部加 chevron。
- `MemeLogo`：空代码时显示上传相机图标（text3），不再是「?」（发起 v2 发射 / 创建代币的资料步预览）。

### MEME v2 项目页

- 外盘交易 / 公开内盘 / 提前购面板标题与 官方池 / 回购 / 发射规则 同为 20 / 700（`launch2PanelHeadingStyle`），面板上方
  24 的段落间距（`launch2PanelTopGap`），读数不再贴着标题。
- 金额口径行（按支付 / 按买入数量 / 按卖出数量 / 按到手金额）放在「输入方式」小标题下，与「滑点上限」同一语法；
  不再是与买卖分段一模一样的第二排胶囊。「按到手」改「按到手金额」。
- 「也可以在钱包兑换里交易」由加粗 TextButton 改为页边距上的 13 字号 text2 链接 + chevron，44 高（key 不变）。
- 买入侧持仓行只写「持有 X $T」（「可卖」是卖出侧的数）；卖出侧不变。
- 无持有人直开公开内盘的提示改为一行：「无 NFT 持有人，直接开放公开内盘，跳过提前购。」（常量去掉「已」）。
- 签名出口两步条：下一步的圆点填 card2、1.5 Chalk 描边、标签 Chalk、说明「下一步，待签名」；之后的步骤退为 text2 / text3。

### 挖矿

- 我的挖矿 / 算力明细 构成行：「0 × 0.9×」→「0 × 权重 0.9」（与标题「持有量 × 权重」同序，去掉悬空的第二个 ×）。
- 邀请关系加成卡：「…当前加成 —。」→「…你的加成在邀请页查看。」（本页从不读加成）。
- 算力明细：hero 句改「逐个资产列出贡献、排除状态与来源。」（原句孤字「明。」换行）；总算力下的说明「当前算力公式」
  →「按当前算力公式计算」。
- 挖矿奖励：`MINING_NOTHING_SETTLED` 时 hero 标题「你有算力的小时还没有结算」（`miningAwaitingTitle`），正文改为下一步
  「挖矿规则已生效。每个整点结算上一小时，结算后这里按分钟展示，并可领取。」（原标题与正文重复）；领取说明
  「有算力的小时结算后可领取」；NFT / Meme 币轨道「有算力的小时结算后显示」；「当前可领取」为 0 时不用 Lime。
  非 `MINING_NOTHING_SETTLED` 的等待态沿用「首个小时结算后开始展示奖励」。

### 钱包

- 「产生算力」抽屉的算力条：算力为 0（或读不到）时用安静卡面、不用 Lime；句子在 0 时为「钱包持仓按权重产生算力」，
  非 0 时才说「正在产生算力」；「今日预估 — LOOP」→「今日预估暂无」。

## 与下单描述的偏离

- 独立评审没有操作模拟器：主机负载 15–30 时模拟器 system_server 多次被看门狗重启、App 在按键 / GPU fence 上 ANR，
  两个进程共用一个输入流会互相点到 ANR 对话框。评审改为读 before / after 截图（路径写进评审提示），其余按技能的提示词与
  打分标准；同一 opus 模型、与实施方无上下文关系。
- `flutter run --profile` 安装 196 MB 包两次触发 system_server 看门狗；改为 `flutter build apk --profile
  --target-platform android-arm64 --dart-define-from-file=config/debug.json` + 熄屏 `adb install -r --skip-verification`，
  dart-define 与 profile 模式和下单一致。
- 「NFT 发售中」态没有截到：第四轮实例 `S1371AE4` 在本批第一张截图（13:08）时已是提前购，15:09 前已毕业；`S1378A05`
  无持有人直开公开内盘；`S13706F2` 17:32 才开售。NFT 发售 / 提前购面板未逐屏打磨，只改了共用的面板标题与对齐。

## Consequences

- 新测试 `test/s151_ui_polish_test.dart`（10 条：签名事实表列对齐与 2 : 3、`LoopKeyValue` 默认不变、价格行占位形状、
  `LoopSegBar` 去边距、算力条两行与 chevron、兑换链接贴页边距且 44 高、面板标题字号、奖励等待标题、两步条下一步、
  `MemeLogo` 空代码）。更新：`s7_mining_pages_test`、`s59_mining_recorded_page_test`、`s149_s148_api_contract_test`（构成行
  算式）、`s138_mining_rewards_test`（等待文案）、`s146_launch2_pool_trade_test`（买入侧持仓行）、`s136_launch2_user_test`
  （无持有人提示常量）。
- `scripts/check_harness.py` 在基线 91ab8b0 已失败一条（`launch2_sign_screen.dart:332` 把 `reasonCode` 直接给 `trailing`），
  本批未碰该文件，留给主代理。

## 未决 / 未修（原因）

1. 评审仍指出但超出打磨范围的：挖矿页 Lime hero 卡 + 点阵、算力明细 hero 的环与光晕、英文 eyebrow、带卡片与分隔线的
   记录组、主按钮的 lift 光晕、滑点的描边选择样式、签名抽屉卡中卡与表头两个徽标（原型结构或 token）。
2. 「当前算力公式」基线标签在算力条数字行里仍像一个链接（0121 要求计算值旁标注，未删）。
3. 已毕业报价块里「滑点上限 1%」与下方滑点选择器重复（0145 明确列入报价行，未改）。
4. 回购卡「下一笔：旧版合约价格保护生效，暂不执行」与 keeper 行「回购暂缓：旧版合约价格保护生效 · HH:mm 后再试」
   同一原因说两次（0146 未决 3：来源不同，合并需裁决）。
5. ADA 等透明底资产 logo 在黑底上几乎不可见（素材问题，不在 `LoopTokenLogo` 加底色以免改变全部 logo）。
6. 「Launch 链」段只显示 tBNB；qa-privy2 持有的 200 tUSD1 不在此段（数据范围问题，需主代理确认是否应显示）。
7. 模拟器上 App 多次 ANR（`Input dispatching timed out` 于软键盘按键 / 「Buffer processing hung up due to stuck fence」），
   在主机负载 15 以上、swiftshader 渲染时出现，未在真机复现；需要真机确认不是 App 主线程问题。
