// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GDXNovaV21 {
    string public name = "GDX Nova";
    string public symbol = "GDX";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1_000_000 * 10**uint256(decimals);

    address public owner;
    bool public isShutdown = false;
    bool public tradingPaused = false;
    bool public mintingAllowed = true;

    uint256 public maxWalletPercent = 5;
    uint256 public cooldownTime = 60;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public blacklist;
    mapping(address => uint256) public lastTransfer;
    mapping(address => uint256) public vestingLock;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed burner, uint256 value);
    event Airdrop(address indexed to, uint256 amount);
    event Shutdown(bool status);
    event Mint(address indexed to, uint256 amount);
    event TradingPaused(bool status);
    event MintingDisabled();
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier notBlacklisted(address user) {
        require(!blacklist[user], "Address is blacklisted");
        _;
    }

    modifier notShutdown() {
        require(!isShutdown, "Contract is shut down");
        _;
    }

    modifier tradingOpen(address from, address to) {
        if (!tradingPaused || msg.sender == owner) {
            if (from != owner && to != owner) {
                require(block.timestamp >= lastTransfer[from] + cooldownTime, "Cooldown active");
                lastTransfer[from] = block.timestamp;
                if (to != address(0)) {
                    require(
                        balanceOf[to] + 1 <= (totalSupply * maxWalletPercent) / 100,
                        "Exceeds wallet limit"
                    );
                }
            }
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
        emit Transfer(address(0), owner, totalSupply);
    }

    function transfer(address to, uint256 value)
        public
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        notShutdown
        tradingOpen(msg.sender, to)
        returns (bool)
    {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        require(block.timestamp >= vestingLock[msg.sender], "Tokens are locked");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        public
        notShutdown
        returns (bool)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        public
        notBlacklisted(from)
        notBlacklisted(to)
        notShutdown
        tradingOpen(from, to)
        returns (bool)
    {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        require(block.timestamp >= vestingLock[from], "Tokens are locked");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function burn(uint256 amount) public notShutdown returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient tokens to burn");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Burn(msg.sender, amount);
        return true;
    }

    function airdrop(address[] calldata recipients, uint256 amount) public onlyOwner notShutdown {
        require(balanceOf[msg.sender] >= amount * recipients.length, "Insufficient balance for airdrop");
        for (uint i = 0; i < recipients.length; i++) {
            balanceOf[msg.sender] -= amount;
            balanceOf[recipients[i]] += amount;
            emit Transfer(msg.sender, recipients[i], amount);
            emit Airdrop(recipients[i], amount);
        }
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(mintingAllowed, "Minting is disabled");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Mint(to, amount);
        emit Transfer(address(0), to, amount);
    }

    function disableMinting() public onlyOwner {
        mintingAllowed = false;
        emit MintingDisabled();
    }

    function setVesting(address wallet, uint256 unlockTime) public onlyOwner {
        vestingLock[wallet] = unlockTime;
    }

    function pauseTrading(bool status) public onlyOwner {
        tradingPaused = status;
        emit TradingPaused(status);
    }

    function shutdown() public onlyOwner {
        isShutdown = true;
        emit Shutdown(true);
    }

    function setWalletLimit(uint256 percent) public onlyOwner {
        require(percent >= 1 && percent <= 100, "Invalid percent");
        maxWalletPercent = percent;
    }

    function blacklistAddress(address user, bool status) public onlyOwner {
        blacklist[user] = status;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function projectAuthor() public pure returns (string memory) {
        return "GDX Nova (c) 2025. All rights reserved.";
    }
}
