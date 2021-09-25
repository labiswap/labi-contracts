pragma solidity ^0.6.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'SafeMath: addition overflow');

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, 'SafeMath: subtraction overflow');
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, 'SafeMath: multiplication overflow');

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, 'SafeMath: division by zero');
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, 'SafeMath: modulo by zero');
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool ok);
}

contract Ico {
    using SafeMath for uint256;

    IBEP20 public TOKEN;
    
    address payable public owner;

    uint256 public startDate;                       // ico sale start date
    uint256 public endDate;                         // ico sale end date

    uint256 public totalAmount;                     // total token amount to sell
    uint256 public minPerTransaction;               // min amount per transaction
    uint256 public maxPerUser;                      // max amount per user
    uint256 public soldAmount;                      // token amount sold so far

    uint256 public tokenPrice;                      // token amount per 1 bnb
    mapping(address => uint256) public tokenPerAddresses;

    uint256 public constant DEFAULT_DECIMALS = 10 ** 18;

    event tokensBought(address indexed user, uint256 amountSpent, uint256 amountBought, string tokenName, uint256 date);
    event tokensClaimed(address indexed user, uint256 amount, uint256 date);
    event OwnershipTransferred(address prevOwner, address newOwner);
    event SetStartDate(uint256 prevDate, uint256 newDate);
    event SetEndDate(uint256 prevDate, uint256 newDate);
    event IcoEnded();
    event SetTotalAmount(uint256 _prevAmount, uint256 newAmount);
    event SetMaxPerUser(uint256 _prevValue, uint256 newValue);
    event SetMinPerTransaction(uint256 _prevValue, uint256 newValue);
    event SetTokenPrice(uint256 _prevPrice, uint256 newPrice);
    event CollectPaidFunds(address owner, uint256 amount);
    event CollectRemainedTokens(address owner, uint256 amount);

    modifier validate(uint256 buyAmount) {
        require(now >= startDate && now < endDate, 'Ico time mismatch');
        require(buyAmount >= minPerTransaction, "Too small amount");
        require(
            buyAmount > 0 && buyAmount <= remainedTokenAmount(),
            'Insufficient buy amount'
        );
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Forbidden");
        _;
    }

    constructor(
        IBEP20  _TOKEN
    ) public {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
        TOKEN = _TOKEN;
    }

    // Function to buy TOKEN using BNB token
    function buyWithBNB(uint256 buyAmount) public payable validate(buyAmount) {
        uint256 amount = calculateBNBAmount(buyAmount);
        require(msg.value >= amount, 'Insufficient BNB balance');
        
        uint256 sumSoFar = tokenPerAddresses[msg.sender].add(buyAmount);
        require(maxPerUser == 0 || sumSoFar <= maxPerUser, 'Exceeds the maximum buyable amount');

        tokenPerAddresses[msg.sender] = sumSoFar;
        soldAmount = soldAmount.add(buyAmount);
                
        emit tokensBought(msg.sender, amount, buyAmount, 'BNB', now);
    }

    // Function to claim 
    function claimToken() external {
        require(now >= endDate, "Ico not ended yet");
        uint256 claimableAmount = tokenPerAddresses[msg.sender];
        require(claimableAmount > 0, "Nothing to claim");
        TOKEN.transfer(msg.sender, claimableAmount);
        tokenPerAddresses[msg.sender] = 0;

        emit tokensClaimed(msg.sender, claimableAmount, now);
    }

    // function to change the owner
    // only owner can call this function
    function changeOwner(address payable _owner) public onlyOwner {
        emit OwnershipTransferred(owner, _owner);
        owner = _owner;
    }

    // function to set the ico start date
    // only owner can call this function
    function setStartDate(uint256 _startDate) external onlyOwner {
        require(now < startDate && now < _startDate, "Past date can not be set");
        require(_startDate < endDate, "Must be before then the end date");
        require(startDate != _startDate, "Same value already set");
        emit SetStartDate(startDate, _startDate);
        startDate = _startDate;
    }

    // function to set the presale end date
    // only owner can call this function
    function setEndDate(uint256 _endDate) public onlyOwner {
        require(startDate < _endDate, "End date should be after start date");
        require(now < _endDate, "Past date can not be set");
        require(endDate != _endDate, "Same value already set");
        emit SetEndDate(endDate, _endDate);
        endDate = _endDate;
    }

    // function to set the total tokens to sell
    // only owner can call this function
    function setTotalAmount(uint256 _totalAmount) external onlyOwner {
        require(_totalAmount >= soldAmount, "More amount already sold");
        require(totalAmount != _totalAmount, "Same value already set");
        emit SetTotalAmount(totalAmount, _totalAmount);
        totalAmount = _totalAmount;
    }

    // function to set the minimal transaction amount
    // only owner can call this function
    function setMinPerTransaction(uint256 _minPerTransaction) external onlyOwner {
        require(_minPerTransaction <= maxPerUser, "Min per transaction must be less than max per user");
        require(minPerTransaction != _minPerTransaction, "Same value already set");
        emit SetMinPerTransaction(minPerTransaction, _minPerTransaction);
        minPerTransaction = _minPerTransaction;
    }

    // function to set the maximum amount which a user can buy
    // only owner can call this function
    function setMaxPerUser(uint256 _maxPerUser) external onlyOwner {
        require(minPerTransaction <= _maxPerUser, "Max per user must be more than min per transaction");
        require(maxPerUser != _maxPerUser, "Same value already set");
        emit SetMaxPerUser(maxPerUser, _maxPerUser);
        maxPerUser = _maxPerUser;
    }
    
    // function to end the ico
    // only owner can call this function
    function endIco() external onlyOwner {
        require(now < endDate, "Already ended");
        endDate = now;
        emit IcoEnded();
    }

    // function to withdraw paid funds.
    // only owner can call this function

    function collectPaidFunds() external onlyOwner {
        require(now >= endDate, "Ico not ended");
        uint256 balance = address(this).balance;
        require(balance > 0, "Insufficient balance");
        owner.transfer(balance);
        emit CollectPaidFunds(owner, balance);
    }

    // function to withdraw unsold tokens
    // only owner can call this function
    function collectRemainedTokens() public onlyOwner {
        require(now >= endDate, "Ico not ended");
        uint256 remainedTokens = remainedTokenAmount();
        require(remainedTokens > 0, "No remained tokens");
        TOKEN.transfer(owner, remainedTokens);
        emit CollectRemainedTokens(owner, remainedTokens);
    }

    //function to return the amount of unsold tokens
    function remainedTokenAmount() public view returns (uint256) {
        return TOKEN.balanceOf(address(this));
    }

    // function to set token amount per 1 bnb
    function setTokenPrice(uint256 _tokenPrice) public onlyOwner {
        require(_tokenPrice > 0, "Invalid token price");
        require(now < startDate, "Ico started already");
        require(tokenPrice != _tokenPrice, "");
        emit SetTokenPrice(tokenPrice, _tokenPrice);
        tokenPrice = _tokenPrice;
    }

    // function to calculate the quantity of TOKEN based on the TOKEN price of bnbAmount
    function calculateTokenAmount(uint256 bnbAmount) public view returns (uint256) {
        uint256 tokenAmount = tokenPrice.mul(bnbAmount).div(DEFAULT_DECIMALS);
        return tokenAmount;
    }

    //function to calculate the quantity of bnb needed using its TOKEN price to buy `buyAmount` of TOKEN
    function calculateBNBAmount(uint256 tokenAmount) public view returns (uint256) {
        require(tokenPrice > 0, "TOKEN price per BNB should be greater than 0");
        uint256 bnbAmount = tokenAmount.mul(DEFAULT_DECIMALS).div(tokenPrice);
        return bnbAmount;
    }
}
