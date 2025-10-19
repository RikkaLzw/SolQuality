
pragma solidity ^0.8.0;

contract PaymentDistribution {
    address public owner;
    uint256 public totalShares;
    bool public distributionActive;

    struct Beneficiary {
        address payable wallet;
        uint256 shares;
        uint256 totalReceived;
        bool active;
    }

    mapping(address => Beneficiary) public beneficiaries;
    mapping(address => bool) public isBeneficiary;
    address[] public beneficiaryList;

    event BeneficiaryAdded(address indexed beneficiary, uint256 shares);
    event BeneficiaryRemoved(address indexed beneficiary);
    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentDistributed(uint256 totalAmount);
    event SharesUpdated(address indexed beneficiary, uint256 newShares);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveBeneficiary(address _beneficiary) {
        require(isBeneficiary[_beneficiary] && beneficiaries[_beneficiary].active, "Not an active beneficiary");
        _;
    }

    constructor() {
        owner = msg.sender;
        distributionActive = true;
    }

    function addBeneficiary(address payable _beneficiary, uint256 _shares) external onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_shares > 0, "Shares must be greater than 0");
        require(!isBeneficiary[_beneficiary], "Beneficiary already exists");

        beneficiaries[_beneficiary] = Beneficiary({
            wallet: _beneficiary,
            shares: _shares,
            totalReceived: 0,
            active: true
        });

        isBeneficiary[_beneficiary] = true;
        beneficiaryList.push(_beneficiary);
        totalShares += _shares;

        emit BeneficiaryAdded(_beneficiary, _shares);
    }

    function removeBeneficiary(address _beneficiary) external onlyOwner onlyActiveBeneficiary(_beneficiary) {
        totalShares -= beneficiaries[_beneficiary].shares;
        beneficiaries[_beneficiary].active = false;

        for (uint256 i = 0; i < beneficiaryList.length; i++) {
            if (beneficiaryList[i] == _beneficiary) {
                beneficiaryList[i] = beneficiaryList[beneficiaryList.length - 1];
                beneficiaryList.pop();
                break;
            }
        }

        emit BeneficiaryRemoved(_beneficiary);
    }

    function updateShares(address _beneficiary, uint256 _newShares) external onlyOwner onlyActiveBeneficiary(_beneficiary) {
        require(_newShares > 0, "Shares must be greater than 0");

        totalShares = totalShares - beneficiaries[_beneficiary].shares + _newShares;
        beneficiaries[_beneficiary].shares = _newShares;

        emit SharesUpdated(_beneficiary, _newShares);
    }

    function distributePayment() external onlyOwner {
        require(distributionActive, "Distribution is not active");
        require(totalShares > 0, "No beneficiaries to distribute to");

        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to distribute");

        for (uint256 i = 0; i < beneficiaryList.length; i++) {
            address beneficiaryAddr = beneficiaryList[i];
            Beneficiary storage beneficiary = beneficiaries[beneficiaryAddr];

            if (beneficiary.active) {
                uint256 payment = (contractBalance * beneficiary.shares) / totalShares;
                if (payment > 0) {
                    beneficiary.totalReceived += payment;
                    beneficiary.wallet.transfer(payment);
                }
            }
        }

        emit PaymentDistributed(contractBalance);
    }

    function setDistributionStatus(bool _active) external onlyOwner {
        distributionActive = _active;
    }

    function getBeneficiaryCount() external view returns (uint256) {
        return beneficiaryList.length;
    }

    function getBeneficiaryInfo(address _beneficiary) external view returns (
        address wallet,
        uint256 shares,
        uint256 totalReceived,
        bool active
    ) {
        require(isBeneficiary[_beneficiary], "Beneficiary does not exist");
        Beneficiary memory beneficiary = beneficiaries[_beneficiary];
        return (beneficiary.wallet, beneficiary.shares, beneficiary.totalReceived, beneficiary.active);
    }

    function calculatePaymentShare(address _beneficiary) external view returns (uint256) {
        require(isBeneficiary[_beneficiary] && beneficiaries[_beneficiary].active, "Not an active beneficiary");
        require(totalShares > 0, "No total shares");

        uint256 contractBalance = address(this).balance;
        return (contractBalance * beneficiaries[_beneficiary].shares) / totalShares;
    }

    receive() external payable {
        require(msg.value > 0, "Payment must be greater than 0");
        emit PaymentReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        require(msg.value > 0, "Payment must be greater than 0");
        emit PaymentReceived(msg.sender, msg.value);
    }
}
