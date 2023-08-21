pragma solidity ^0.8.14;

import './lib/Tick.sol';
import './lib/Position.sol';

contract UniswapV3Pool {
  // 每个池子合约都包含一些 tick 的信息，需要一个 mapping 来存储 tick 的下标与对应的信息
  using Tick for mapping(int24 => Tick.Info);

  // 跟踪现在的价格和对应的 tick。我们将会把他们存储在一个 slot 中来节省 gas 费
  using Position for mapping(bytes32 => Position.Info);
  using Position for Position.Info;

  int24 internal constant MIN_TICK = -887272;
  int24 internal constant MAX_TICK = -MIN_TICK;


  address public immutable token0;
  address public immutable token1;

  struct Slot0 {
    uint160 sqrtPriceX96;
    int24 tick;
  }

  Slot0 public slot0;

  uint128 public liquidity;

  mapping(int24 => Tick.Info) public ticks;
  mapping(bytes32 => Position.Info) public positions;


  constructor(
    address token0_,
    address token1_,
    uint160 sqrtPriceX96,
    int24 tick
  ) {
    token0 = token0_;
    token1 = token1_;

    slot0 = Slot0({ sqrtPriceX96: sqrtPriceX96, tick: tick });
  }

}
