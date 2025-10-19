
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract PaymentSplitterContract is Ownable, ReentrancyGuard, Pausable {
    using Address for address payable;


    uint256 private constant MAX_BENEFICIARIES = 100;
    uint256 private constant MIN_SHARE = 1;
    uint256 private constant PRECISION = 10000;


    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _beneficiaries;
    uint256 private _totalShares;
    uint256 private _totalReleased;


    event BeneficiaryAdded(address indexed beneficiary, uint256 shares);
    event BeneficiaryRemoved(address indexed beneficiary);
    event SharesUpdated(address indexed beneficiary, uint256 oldShares, uint256 newShares);
    event PaymentReleased(address indexed to, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);


    modifier validBeneficiary(address beneficiary) {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(beneficiary != address(this), "Cannot be contract address");
        _;
    }

    modifier beneficiaryExists(address beneficiary) {
        require(_shares[beneficiary] > 0, "Beneficiary does not exist");
        _;
    }

    modifier beneficiaryNotExists(address beneficiary) {
        require(_shares[beneficiary] == 0, "Beneficiary already exists");
        _;
    }

    modifier validShares(uint256 shares) {
        require(shares >= MIN_SHARE, "Shares must be at least 1");
        _;
    }

    modifier maxBeneficiariesNotExceeded() {
        require(_beneficiaries.length < MAX_BENEFICIARIES, "Max beneficiaries exceeded");
        _;
    }


    constructor(address[] memory beneficiaries, uint256[] memory shares) {
        require(beneficiaries.length > 0, "At least one beneficiary required");
        require(beneficiaries.length == shares.length, "Arrays length mismatch");
        require(beneficiaries.length <= MAX_BENEFICIARIES, "Too many beneficiaries");

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            _addBeneficiary(beneficiaries[i], shares[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    fallback() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function addBeneficiary(address beneficiary, uint256 shares)
        external
        onlyOwner
        whenNotPaused
        validBeneficiary(beneficiary)
        beneficiaryNotExists(beneficiary)
        validShares(shares)
        maxBeneficiariesNotExceeded
    {
        _addBeneficiary(beneficiary, shares);
    }


    function removeBeneficiary(address beneficiary)
        external
        onlyOwner
        whenNotPaused
        beneficiaryExists(beneficiary)
    {
        _removeBeneficiary(beneficiary);
    }


    function updateShares(address beneficiary, uint256 newShares)
        external
        onlyOwner
        whenNotPaused
        beneficiaryExists(beneficiary)
        validShares(newShares)
    {
        uint256 oldShares = _shares[beneficiary];
        _totalShares = _totalShares - oldShares + newShares;
        _shares[beneficiary] = newShares;

        emit SharesUpdated(beneficiary, oldShares, newShares);
    }


    function release(address payable beneficiary)
        external
        nonReentrant
        whenNotPaused
        beneficiaryExists(beneficiary)
    {
        uint256 payment = _calculatePendingPayment(beneficiary);
        require(payment > 0, "No payment due");

        _released[beneficiary] += payment;
        _totalReleased += payment;

        beneficiary.sendValue(payment);
        emit PaymentReleased(beneficiary, payment);
    }


    function releaseAll() external nonReentrant whenNotPaused {
        uint256 beneficiaryCount = _beneficiaries.length;
        require(beneficiaryCount > 0, "No beneficiaries");

        for (uint256 i = 0; i < beneficiaryCount; i++) {
            address payable beneficiary = payable(_beneficiaries[i]);
            uint256 payment = _calculatePendingPayment(beneficiary);

            if (payment > 0) {
                _released[beneficiary] += payment;
                _totalReleased += payment;
                beneficiary.sendValue(payment);
                emit PaymentReleased(beneficiary, payment);
            }
        }
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function totalShares() external view returns (uint256) {
        return _totalShares;
    }


    function totalReleased() external view returns (uint256) {
        return _totalReleased;
    }


    function shares(address beneficiary) external view returns (uint256) {
        return _shares[beneficiary];
    }


    function released(address beneficiary) external view returns (uint256) {
        return _released[beneficiary];
    }


    function getBeneficiaries() external view returns (address[] memory) {
        return _beneficiaries;
    }


    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function pendingPayment(address beneficiary) external view returns (uint256) {
        return _calculatePendingPayment(beneficiary);
    }


    function _addBeneficiary(address beneficiary, uint256 shares) private {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(shares > 0, "Shares must be greater than 0");
        require(_shares[beneficiary] == 0, "Beneficiary already exists");

        _beneficiaries.push(beneficiary);
        _shares[beneficiary] = shares;
        _totalShares += shares;

        emit BeneficiaryAdded(beneficiary, shares);
    }


    function _removeBeneficiary(address beneficiary) private {
        uint256 beneficiaryShares = _shares[beneficiary];


        uint256 payment = _calculatePendingPayment(beneficiary);
        if (payment > 0) {
            _released[beneficiary] += payment;
            _totalReleased += payment;
            payable(beneficiary).sendValue(payment);
            emit PaymentReleased(beneficiary, payment);
        }


        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            if (_beneficiaries[i] == beneficiary) {
                _beneficiaries[i] = _beneficiaries[_beneficiaries.length - 1];
                _beneficiaries.pop();
                break;
            }
        }


        _totalShares -= beneficiaryShares;
        delete _shares[beneficiary];
        delete _released[beneficiary];

        emit BeneficiaryRemoved(beneficiary);
    }


    function _calculatePendingPayment(address beneficiary) private view returns (uint256) {
        if (_totalShares == 0) return 0;

        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 payment = (totalReceived * _shares[beneficiary]) / _totalShares;

        return payment - _released[beneficiary];
    }
}
