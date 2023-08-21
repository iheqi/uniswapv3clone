// 跟踪现在的价格和对应的 tick。我们将会把他们存储在一个 slot 中来节省 gas 费

library Position {
  struct Info {
    uint128 liquidity;
  }

  function update(Info storage self, uint128 liquidityDelta) internal {
    uint128 liquidityBefore = self.liquidity;
    uint128 liquidityAfter = liquidityBefore + liquidityDelta;
    self.liquidity = liquidityAfter;
  }

  // 每个位置都由三个变量所确定：LP 地址，下界 tick 下标，上界 tick 下标。
  // 我们将这三个变量哈希来减少数据存储开销：哈希结果只有 32 字节，而三个变量分别存储需要 96 字节
  function get(
    mapping(bytes32 => Info) storage self,
    address owner,
    int24 lowerTick,
    int24 upperTick
  ) internal view returns (Position.Info storage position) {
    position = self[keccak256(abi.encodePacked(owner, lowerTick, upperTick))];
  }
}
