
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract PaymentDistribution is Ownable, ReentrancyGuard {
    using Address for address payable;


    uint256 public constant MAX_BENEFICIARIES = 100;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_SHARE = 1;


    struct Beneficiary {
        address payable account;
        uint256 share;
        uint256 totalReceived;
    }

    mapping(address => uint256) private _beneficiaryIndex;
    Beneficiary[] private _beneficiaries;
    uint256 private _totalShares;
    uint256 private _totalDistributed;
    bool private _distributionEnabled;


    event BeneficiaryAdded(address indexed account, uint256 share);
    event BeneficiaryRemoved(address indexed account);
    event ShareUpdated(address indexed account, uint256 oldShare, uint256 newShare);
    event PaymentDistributed(uint256 amount, uint256 timestamp);
    event PaymentReceived(address indexed from, uint256 amount);
    event DistributionStatusChanged(bool enabled);


    modifier onlyValidAddress(address account) {
        require(account != address(0), "Invalid address");
        require(account != address(this), "Cannot be contract address");
        _;
    }

    modifier onlyValidShare(uint256 share) {
        require(share >= MIN_SHARE && share <= BASIS_POINTS, "Invalid share");
        _;
    }

    modifier onlyExistingBeneficiary(address account) {
        require(_isBeneficiary(account), "Not a beneficiary");
        _;
    }

    modifier onlyNonExistingBeneficiary(address account) {
        require(!_isBeneficiary(account), "Already a beneficiary");
        _;
    }

    modifier onlyWhenDistributionEnabled() {
        require(_distributionEnabled, "Distribution disabled");
        _;
    }

    modifier onlyValidBeneficiaryCount() {
        require(_beneficiaries.length < MAX_BENEFICIARIES, "Too many beneficiaries");
        _;
    }

    constructor() {
        _distributionEnabled = true;
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
        if (_distributionEnabled && address(this).balance > 0) {
            _distributePayments();
        }
    }

    function addBeneficiary(address payable account, uint256 share)
        external
        onlyOwner
        onlyValidAddress(account)
        onlyValidShare(share)
        onlyNonExistingBeneficiary(account)
        onlyValidBeneficiaryCount
    {
        require(_totalShares + share <= BASIS_POINTS, "Total shares exceed 100%");

        _beneficiaries.push(Beneficiary({
            account: account,
            share: share,
            totalReceived: 0
        }));

        _beneficiaryIndex[account] = _beneficiaries.length;
        _totalShares += share;

        emit BeneficiaryAdded(account, share);
    }

    function removeBeneficiary(address account)
        external
        onlyOwner
        onlyExistingBeneficiary(account)
    {
        uint256 index = _getBeneficiaryIndex(account);
        uint256 share = _beneficiaries[index].share;


        _beneficiaries[index] = _beneficiaries[_beneficiaries.length - 1];
        _beneficiaryIndex[_beneficiaries[index].account] = index + 1;

        _beneficiaries.pop();
        delete _beneficiaryIndex[account];
        _totalShares -= share;

        emit BeneficiaryRemoved(account);
    }

    function updateBeneficiaryShare(address account, uint256 newShare)
        external
        onlyOwner
        onlyExistingBeneficiary(account)
        onlyValidShare(newShare)
    {
        uint256 index = _getBeneficiaryIndex(account);
        uint256 oldShare = _beneficiaries[index].share;

        require(_totalShares - oldShare + newShare <= BASIS_POINTS, "Total shares exceed 100%");

        _beneficiaries[index].share = newShare;
        _totalShares = _totalShares - oldShare + newShare;

        emit ShareUpdated(account, oldShare, newShare);
    }

    function distributePayments() external onlyWhenDistributionEnabled nonReentrant {
        require(address(this).balance > 0, "No balance to distribute");
        _distributePayments();
    }

    function setDistributionEnabled(bool enabled) external onlyOwner {
        _distributionEnabled = enabled;
        emit DistributionStatusChanged(enabled);
    }

    function emergencyWithdraw() external onlyOwner {
        require(!_distributionEnabled, "Distribution must be disabled");
        payable(owner()).sendValue(address(this).balance);
    }


    function getBeneficiary(address account)
        external
        view
        onlyExistingBeneficiary(account)
        returns (address, uint256, uint256)
    {
        uint256 index = _getBeneficiaryIndex(account);
        Beneficiary memory beneficiary = _beneficiaries[index];
        return (beneficiary.account, beneficiary.share, beneficiary.totalReceived);
    }

    function getAllBeneficiaries() external view returns (Beneficiary[] memory) {
        return _beneficiaries;
    }

    function getBeneficiaryCount() external view returns (uint256) {
        return _beneficiaries.length;
    }

    function getTotalShares() external view returns (uint256) {
        return _totalShares;
    }

    function getTotalDistributed() external view returns (uint256) {
        return _totalDistributed;
    }

    function getDistributionEnabled() external view returns (bool) {
        return _distributionEnabled;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function _distributePayments() internal {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to distribute");
        require(_beneficiaries.length > 0, "No beneficiaries");

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            uint256 payment = _calculatePayment(balance, _beneficiaries[i].share);
            if (payment > 0) {
                _beneficiaries[i].totalReceived += payment;
                _beneficiaries[i].account.sendValue(payment);
            }
        }

        _totalDistributed += balance;
        emit PaymentDistributed(balance, block.timestamp);
    }

    function _calculatePayment(uint256 totalAmount, uint256 share) internal pure returns (uint256) {
        return (totalAmount * share) / BASIS_POINTS;
    }

    function _isBeneficiary(address account) internal view returns (bool) {
        return _beneficiaryIndex[account] != 0;
    }

    function _getBeneficiaryIndex(address account) internal view returns (uint256) {
        uint256 index = _beneficiaryIndex[account];
        require(index != 0, "Beneficiary not found");
        return index - 1;
    }
}
