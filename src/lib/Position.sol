// 跟踪现在的价格和对应的 tick。我们将会把他们存储在一个 slot 中来节省 gas 费

library Position {
  struct Info {
    uint128 liquidity;
  }
}
