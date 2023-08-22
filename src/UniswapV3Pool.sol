pragma solidity ^0.8.14;

import './lib/Tick.sol';
import './lib/Position.sol';

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV3MintCallback.sol";
import "./interfaces/IUniswapV3SwapCallback.sol";

contract UniswapV3Pool {
  using Tick for mapping(int24 => Tick.Info);
  using Position for mapping(bytes32 => Position.Info);
  using Position for Position.Info;

  error InsufficientInputAmount();
  error InvalidTickRange();
  error ZeroLiquidity();

  event Mint(
      address sender,
      address indexed owner,
      int24 indexed tickLower,
      int24 indexed tickUpper,
      uint128 amount,
      uint256 amount0,
      uint256 amount1
  );
  event Swap(
      address indexed sender,
      address indexed recipient,
      int256 amount0,
      int256 amount1,
      uint160 sqrtPriceX96,
      uint128 liquidity,
      int24 tick
  );
  int24 internal constant MIN_TICK = -887272;
  int24 internal constant MAX_TICK = -MIN_TICK;


  address public immutable token0;
  address public immutable token1;

  struct Slot0 {
    uint160 sqrtPriceX96; // 当前的价格
    int24 tick;           // 当前的tick
  }

  Slot0 public slot0;

  uint128 public liquidity;

  // 每个池子合约都包含一些 tick 的信息，需要一个 mapping 来存储 tick 的下标与对应的信息
  mapping(int24 => Tick.Info) public ticks;

  // 跟踪现在的价格和对应的 tick。我们将会把他们存储在一个 slot 中来节省 gas 费
  mapping(bytes32 => Position.Info) public positions;


  constructor(
    address token0_,
    address token1_,
    uint160 sqrtPriceX96, // 当前的价格
    int24 tick            // 当前的tick
  ) {
    token0 = token0_;
    token1 = token1_;

    slot0 = Slot0({ sqrtPriceX96: sqrtPriceX96, tick: tick });
  }

  // mint 函数包含以下参数：

  // 1.token 所有者的地址，来识别是谁提供的流动性；
  // 2.上界和下界的 tick，来设置价格区间的边界；
  // 3.希望提供的流动性的数量
  function mint(
    address owner, 
    int24 lowerTick, 
    int24 upperTick, 
    uint128 amount
  ) external returns (uint256 amount0, uint256 amount1) {
    
    // 首先来检查 ticks:
    if (
      lowerTick >= upperTick ||
        lowerTick < MIN_TICK ||
        upperTick > MAX_TICK
    ) revert InvalidTickRange();

    // 并且确保提供的流动性数量不为零：
    if (amount == 0) revert ZeroLiquidity();

    // 在下界 tick 和上界 tick 处均调用此函数，流动性在两边都有添加
    ticks.update(lowerTick, amount);
    ticks.update(upperTick, amount);

    Position.Info storage position = positions.get(owner, lowerTick, upperTick);
    position.update(amount);

    amount0 = 0.998976618347425280 ether; // TODO: replace with calculation
    amount1 = 5000 ether; // TODO: replace with calculation

    liquidity += uint128(amount);

    uint256 balance0Before;
    uint256 balance1Before;
    if (amount0 > 0) balance0Before = balance0();
    if (amount1 > 0) balance1Before = balance1();

    IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
      amount0,
      amount1
    );

    if (amount0 > 0 && balance0Before + amount0 > balance0()) revert InsufficientInputAmount();
    if (amount1 > 0 && balance1Before + amount1 > balance1()) revert InsufficientInputAmount();
    emit Mint(msg.sender, owner, lowerTick, upperTick, amount, amount0, amount1);
  }

  function balance0() internal returns (uint256 balance) {
    balance = IERC20(token0).balanceOf(address(this));
  }

  function balance1() internal returns (uint256 balance) {
    balance = IERC20(token1).balanceOf(address(this));
  }


  function swap(address recipient) public returns (int256 amount0, int256 amount1) {
    int24 nextTick = 85184;
    uint160 nextPrice = 5604469350942327889444743441197;

    // 先硬编码我们之前计算出来的值
    amount0 = -0.008396714242162444 ether;
    amount1 = 42 ether;

    // 更新现在的 tick 和对应的 sqrtP
    (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);

    IERC20(token0).transfer(recipient, uint256(-amount0));

    uint256 balance1Before = balance1();
    IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
        amount0,
        amount1
    );

    if (balance1Before + uint256(amount1) < balance1()) revert InsufficientInputAmount();
    
    emit Swap(
      msg.sender,
      recipient,
      amount0,
      amount1,
      slot0.sqrtPriceX96,
      liquidity,
      slot0.tick
    );

  }
}
