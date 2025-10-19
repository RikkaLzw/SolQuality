
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract PaymentDistributionContract is Ownable, ReentrancyGuard {
    using Address for address payable;


    uint256 public constant MAX_RECIPIENTS = 100;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_SHARE = 1;


    struct Recipient {
        address payable wallet;
        uint256 share;
        bool active;
    }

    mapping(address => Recipient) private _recipients;
    address[] private _recipientAddresses;
    uint256 private _totalShares;
    uint256 private _totalDistributed;


    event RecipientAdded(address indexed recipient, uint256 share);
    event RecipientUpdated(address indexed recipient, uint256 oldShare, uint256 newShare);
    event RecipientRemoved(address indexed recipient, uint256 share);
    event PaymentDistributed(uint256 amount, uint256 recipientCount);
    event PaymentReceived(address indexed sender, uint256 amount);


    modifier validRecipient(address recipient) {
        require(recipient != address(0), "Invalid recipient address");
        require(recipient != address(this), "Cannot add contract as recipient");
        _;
    }

    modifier recipientExists(address recipient) {
        require(_recipients[recipient].active, "Recipient does not exist");
        _;
    }

    modifier recipientNotExists(address recipient) {
        require(!_recipients[recipient].active, "Recipient already exists");
        _;
    }

    modifier validShare(uint256 share) {
        require(share >= MIN_SHARE && share <= BASIS_POINTS, "Invalid share amount");
        _;
    }

    modifier hasBalance() {
        require(address(this).balance > 0, "No balance to distribute");
        _;
    }

    modifier maxRecipientsNotReached() {
        require(_recipientAddresses.length < MAX_RECIPIENTS, "Maximum recipients reached");
        _;
    }

    constructor() {}


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function addRecipient(address recipient, uint256 share)
        external
        onlyOwner
        validRecipient(recipient)
        recipientNotExists(recipient)
        validShare(share)
        maxRecipientsNotReached
    {
        require(_totalShares + share <= BASIS_POINTS, "Total shares exceed 100%");

        _recipients[recipient] = Recipient({
            wallet: payable(recipient),
            share: share,
            active: true
        });

        _recipientAddresses.push(recipient);
        _totalShares += share;

        emit RecipientAdded(recipient, share);
    }


    function updateRecipientShare(address recipient, uint256 newShare)
        external
        onlyOwner
        validRecipient(recipient)
        recipientExists(recipient)
        validShare(newShare)
    {
        uint256 oldShare = _recipients[recipient].share;
        uint256 sharesDifference = newShare > oldShare ? newShare - oldShare : oldShare - newShare;

        if (newShare > oldShare) {
            require(_totalShares + sharesDifference <= BASIS_POINTS, "Total shares exceed 100%");
            _totalShares += sharesDifference;
        } else {
            _totalShares -= sharesDifference;
        }

        _recipients[recipient].share = newShare;

        emit RecipientUpdated(recipient, oldShare, newShare);
    }


    function removeRecipient(address recipient)
        external
        onlyOwner
        validRecipient(recipient)
        recipientExists(recipient)
    {
        uint256 share = _recipients[recipient].share;
        _totalShares -= share;


        _removeFromArray(recipient);


        _recipients[recipient].active = false;

        emit RecipientRemoved(recipient, share);
    }


    function distributePayments() external nonReentrant hasBalance {
        require(_totalShares > 0, "No recipients configured");

        uint256 balance = address(this).balance;
        uint256 distributed = 0;
        uint256 activeRecipients = 0;

        for (uint256 i = 0; i < _recipientAddresses.length; i++) {
            address recipientAddr = _recipientAddresses[i];
            Recipient memory recipient = _recipients[recipientAddr];

            if (recipient.active) {
                uint256 amount = (balance * recipient.share) / _totalShares;
                if (amount > 0) {
                    recipient.wallet.sendValue(amount);
                    distributed += amount;
                    activeRecipients++;
                }
            }
        }

        _totalDistributed += distributed;

        emit PaymentDistributed(distributed, activeRecipients);
    }


    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        payable(owner()).sendValue(balance);
    }


    function getRecipient(address recipient)
        external
        view
        returns (address wallet, uint256 share, bool active)
    {
        Recipient memory rec = _recipients[recipient];
        return (rec.wallet, rec.share, rec.active);
    }


    function getActiveRecipients() external view returns (address[] memory) {
        uint256 activeCount = 0;


        for (uint256 i = 0; i < _recipientAddresses.length; i++) {
            if (_recipients[_recipientAddresses[i]].active) {
                activeCount++;
            }
        }


        address[] memory activeRecipients = new address[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < _recipientAddresses.length; i++) {
            if (_recipients[_recipientAddresses[i]].active) {
                activeRecipients[index] = _recipientAddresses[i];
                index++;
            }
        }

        return activeRecipients;
    }


    function getContractStats()
        external
        view
        returns (uint256 totalShares, uint256 totalDistributed, uint256 currentBalance, uint256 recipientCount)
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < _recipientAddresses.length; i++) {
            if (_recipients[_recipientAddresses[i]].active) {
                activeCount++;
            }
        }

        return (_totalShares, _totalDistributed, address(this).balance, activeCount);
    }


    function _removeFromArray(address recipient) private {
        for (uint256 i = 0; i < _recipientAddresses.length; i++) {
            if (_recipientAddresses[i] == recipient) {
                _recipientAddresses[i] = _recipientAddresses[_recipientAddresses.length - 1];
                _recipientAddresses.pop();
                break;
            }
        }
    }
}
