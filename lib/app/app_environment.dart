enum AppEnvironment { development }

enum HyperliquidEnvironment { testnet }

/// Compile-time safety policy for the development and Testnet-only phase.
abstract final class BuildPolicy {
  static const appEnvironment = AppEnvironment.development;
  static const hyperliquidEnvironment = HyperliquidEnvironment.testnet;

  static const mainnetEnabled = false;
  static const withdrawalsEnabled = false;
  static const automatedTradingEnabled = false;
}
