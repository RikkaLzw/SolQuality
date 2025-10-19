
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract PaymentDistributionContract is Ownable, ReentrancyGuard {
    using Address for address payable;


    uint256 public constant MAX_RECIPIENTS = 100;
    uint256 public constant PERCENTAGE_BASE = 10000;
    uint256 public constant MIN_DISTRIBUTION_AMOUNT = 1 ether;


    struct Recipient {
        address payable wallet;
        uint256 share;
        bool active;
    }


    mapping(uint256 => Recipient) private _recipients;
    uint256 private _recipientCount;
    uint256 private _totalShares;
    uint256 private _totalDistributed;

    mapping(address => uint256) private _withdrawableAmounts;
    mapping(address => uint256) private _totalWithdrawn;


    event RecipientAdded(uint256 indexed recipientId, address indexed wallet, uint256 share);
    event RecipientUpdated(uint256 indexed recipientId, address indexed wallet, uint256 share);
    event RecipientRemoved(uint256 indexed recipientId, address indexed wallet);
    event PaymentReceived(address indexed sender, uint256 amount);
    event PaymentDistributed(uint256 totalAmount, uint256 recipientCount);
    event WithdrawalMade(address indexed recipient, uint256 amount);


    modifier validRecipientId(uint256 recipientId) {
        require(recipientId < _recipientCount, "Invalid recipient ID");
        require(_recipients[recipientId].active, "Recipient not active");
        _;
    }

    modifier validShare(uint256 share) {
        require(share > 0 && share <= PERCENTAGE_BASE, "Invalid share percentage");
        _;
    }

    modifier validAddress(address wallet) {
        require(wallet != address(0), "Invalid address");
        require(wallet != address(this), "Cannot be contract address");
        _;
    }

    modifier hasBalance() {
        require(address(this).balance > 0, "No balance to distribute");
        _;
    }

    modifier minDistributionAmount() {
        require(address(this).balance >= MIN_DISTRIBUTION_AMOUNT, "Amount below minimum threshold");
        _;
    }

    constructor() {}


    function addRecipient(address payable wallet, uint256 share)
        external
        onlyOwner
        validAddress(wallet)
        validShare(share)
    {
        require(_recipientCount < MAX_RECIPIENTS, "Maximum recipients reached");
        require(_totalShares + share <= PERCENTAGE_BASE, "Total shares exceed 100%");
        require(!_isRecipientExists(wallet), "Recipient already exists");

        uint256 recipientId = _recipientCount;
        _recipients[recipientId] = Recipient({
            wallet: wallet,
            share: share,
            active: true
        });

        _recipientCount++;
        _totalShares += share;

        emit RecipientAdded(recipientId, wallet, share);
    }


    function updateRecipient(uint256 recipientId, address payable newWallet, uint256 newShare)
        external
        onlyOwner
        validRecipientId(recipientId)
        validAddress(newWallet)
        validShare(newShare)
    {
        Recipient storage recipient = _recipients[recipientId];
        uint256 oldShare = recipient.share;

        require(_totalShares - oldShare + newShare <= PERCENTAGE_BASE, "Total shares exceed 100%");


        if (recipient.wallet != newWallet && _withdrawableAmounts[recipient.wallet] > 0) {

            _withdrawableAmounts[newWallet] += _withdrawableAmounts[recipient.wallet];
            _withdrawableAmounts[recipient.wallet] = 0;
        }

        recipient.wallet = newWallet;
        recipient.share = newShare;
        _totalShares = _totalShares - oldShare + newShare;

        emit RecipientUpdated(recipientId, newWallet, newShare);
    }


    function removeRecipient(uint256 recipientId)
        external
        onlyOwner
        validRecipientId(recipientId)
    {
        Recipient storage recipient = _recipients[recipientId];
        address recipientWallet = recipient.wallet;
        uint256 recipientShare = recipient.share;


        if (_withdrawableAmounts[recipientWallet] > 0) {
            _performWithdrawal(recipientWallet);
        }

        recipient.active = false;
        _totalShares -= recipientShare;

        emit RecipientRemoved(recipientId, recipientWallet);
    }


    function distributePayments()
        external
        onlyOwner
        hasBalance
        minDistributionAmount
        nonReentrant
    {
        require(_totalShares > 0, "No active recipients");

        uint256 totalAmount = address(this).balance;
        uint256 distributedAmount = 0;
        uint256 activeRecipients = 0;

        for (uint256 i = 0; i < _recipientCount; i++) {
            if (_recipients[i].active) {
                uint256 recipientAmount = (totalAmount * _recipients[i].share) / PERCENTAGE_BASE;
                _withdrawableAmounts[_recipients[i].wallet] += recipientAmount;
                distributedAmount += recipientAmount;
                activeRecipients++;
            }
        }

        _totalDistributed += distributedAmount;
        emit PaymentDistributed(distributedAmount, activeRecipients);
    }


    function withdraw() external nonReentrant {
        require(_withdrawableAmounts[msg.sender] > 0, "No funds available for withdrawal");
        _performWithdrawal(msg.sender);
    }


    function _performWithdrawal(address recipient) private {
        uint256 amount = _withdrawableAmounts[recipient];
        _withdrawableAmounts[recipient] = 0;
        _totalWithdrawn[recipient] += amount;

        payable(recipient).sendValue(amount);
        emit WithdrawalMade(recipient, amount);
    }


    function _isRecipientExists(address wallet) private view returns (bool) {
        for (uint256 i = 0; i < _recipientCount; i++) {
            if (_recipients[i].active && _recipients[i].wallet == wallet) {
                return true;
            }
        }
        return false;
    }


    function getRecipient(uint256 recipientId)
        external
        view
        validRecipientId(recipientId)
        returns (address wallet, uint256 share, bool active)
    {
        Recipient memory recipient = _recipients[recipientId];
        return (recipient.wallet, recipient.share, recipient.active);
    }

    function getRecipientCount() external view returns (uint256) {
        return _recipientCount;
    }

    function getTotalShares() external view returns (uint256) {
        return _totalShares;
    }

    function getTotalDistributed() external view returns (uint256) {
        return _totalDistributed;
    }

    function getWithdrawableAmount(address recipient) external view returns (uint256) {
        return _withdrawableAmounts[recipient];
    }

    function getTotalWithdrawn(address recipient) external view returns (uint256) {
        return _totalWithdrawn[recipient];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    fallback() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function emergencyWithdraw() external onlyOwner {
        require(_totalShares == 0, "Cannot withdraw with active recipients");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        payable(owner()).sendValue(balance);
    }
}
