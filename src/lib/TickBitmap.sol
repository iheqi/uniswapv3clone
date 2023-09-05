// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './BitMath.sol';

// TickBitmap 想象为一个无穷的 0/1 数组。
// 数组中每一位都对应一个 tick。为了更好地在数组中寻址，我们把数组按照字的大小划分：每个子数组为 256 位。
library TickBitmap {

  
  function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
    wordPos = int16(tick >> 8);
    bitPos = uint8(uint24(tick % 256));
  } 

  function flipTick(
    mapping(int16 => uint256) storage self,
    int24 tick,
    int24 tickSpacing // wtf
  ) internal {
    require(tick % tickSpacing == 0);
    (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
    uint256 mask = 1 << bitPos;
    self[wordPos] ^ mask;
  }

  // 通过 bitmap 索引来寻找带有流动性的 tick
  function nextInitializedTickWithinOneWord(
    mapping(int16 => uint256) storage self,
    int24 tick,
    int24 tickSpacing,
    bool lte // lte 是一个设置方向的 flag。为 true 时，我们是卖出 token x，在右边寻找下一个 tick；false 时相反。
  ) internal view returns (int24 next, bool initialized) {
    int24 compressed = tick / tickSpacing;
    if (lte) {
      (int16 wordPos, uint8 bitPos) = position(compressed);
      uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
      uint256 masked = self[wordPos] & mask;

      // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
      initialized = masked != 0;
      // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
      next = initialized
          ? (compressed - int24(uint24(bitPos - BitMath.mostSignificantBit(masked)))) * tickSpacing
          : (compressed - int24(uint24(bitPos))) * tickSpacing;
    } else {
      (int16 wordPos, uint8 bitPos) = position(compressed + 1);
      uint256 mask = ~((1 << bitPos) - 1);
      uint256 masked = self[wordPos] & mask;

      // if there are no initialized ticks to the left of the current tick, return leftmost in the word
      initialized = masked != 0;
      // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
      next = initialized
          ? (compressed + 1 + int24(uint24((BitMath.leastSignificantBit(masked) - bitPos)))) * tickSpacing
          : (compressed + 1 + int24(uint24((type(uint8).max - bitPos)))) * tickSpacing;
    }
  }
}