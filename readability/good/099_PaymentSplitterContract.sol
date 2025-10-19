
pragma solidity ^0.8.0;


contract PaymentSplitterContract {


    address[] private beneficiaries;


    mapping(address => uint256) private beneficiaryShares;


    mapping(address => uint256) private withdrawnAmounts;


    uint256 private totalReceived;


    uint256 private totalShares;


    address private contractOwner;


    event PaymentReceived(address indexed sender, uint256 amount);
    event PaymentWithdrawn(address indexed beneficiary, uint256 amount);
    event BeneficiaryAdded(address indexed beneficiary, uint256 shares);
    event BeneficiaryUpdated(address indexed beneficiary, uint256 newShares);


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }


    modifier onlyBeneficiary() {
        require(beneficiaryShares[msg.sender] > 0, "Caller is not a beneficiary");
        _;
    }


    constructor(
        address[] memory initialBeneficiaries,
        uint256[] memory initialShares
    ) {
        require(
            initialBeneficiaries.length == initialShares.length,
            "Beneficiaries and shares arrays must have the same length"
        );
        require(
            initialBeneficiaries.length > 0,
            "Must have at least one beneficiary"
        );

        contractOwner = msg.sender;

        uint256 sharesSum = 0;
        for (uint256 i = 0; i < initialBeneficiaries.length; i++) {
            require(
                initialBeneficiaries[i] != address(0),
                "Beneficiary address cannot be zero"
            );
            require(
                initialShares[i] > 0,
                "Beneficiary share must be greater than zero"
            );

            beneficiaries.push(initialBeneficiaries[i]);
            beneficiaryShares[initialBeneficiaries[i]] = initialShares[i];
            sharesSum += initialShares[i];

            emit BeneficiaryAdded(initialBeneficiaries[i], initialShares[i]);
        }

        require(sharesSum == 10000, "Total shares must equal 10000 (100%)");
        totalShares = sharesSum;
    }


    receive() external payable {
        require(msg.value > 0, "Payment amount must be greater than zero");

        totalReceived += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }


    function calculateWithdrawableAmount(address beneficiaryAddress)
        public
        view
        returns (uint256)
    {
        require(
            beneficiaryShares[beneficiaryAddress] > 0,
            "Address is not a beneficiary"
        );

        uint256 totalEntitled = (totalReceived * beneficiaryShares[beneficiaryAddress]) / 10000;
        uint256 alreadyWithdrawn = withdrawnAmounts[beneficiaryAddress];

        if (totalEntitled > alreadyWithdrawn) {
            return totalEntitled - alreadyWithdrawn;
        } else {
            return 0;
        }
    }


    function withdrawPayment() external onlyBeneficiary {
        uint256 withdrawableAmount = calculateWithdrawableAmount(msg.sender);
        require(withdrawableAmount > 0, "No funds available for withdrawal");

        withdrawnAmounts[msg.sender] += withdrawableAmount;

        (bool success, ) = payable(msg.sender).call{value: withdrawableAmount}("");
        require(success, "Transfer failed");

        emit PaymentWithdrawn(msg.sender, withdrawableAmount);
    }


    function addBeneficiary(address newBeneficiary, uint256 shares)
        external
        onlyOwner
    {
        require(newBeneficiary != address(0), "Beneficiary address cannot be zero");
        require(shares > 0, "Shares must be greater than zero");
        require(
            beneficiaryShares[newBeneficiary] == 0,
            "Beneficiary already exists"
        );
        require(
            totalShares + shares <= 10000,
            "Total shares would exceed 10000"
        );

        beneficiaries.push(newBeneficiary);
        beneficiaryShares[newBeneficiary] = shares;
        totalShares += shares;

        emit BeneficiaryAdded(newBeneficiary, shares);
    }


    function updateBeneficiaryShares(address beneficiaryAddress, uint256 newShares)
        external
        onlyOwner
    {
        require(
            beneficiaryShares[beneficiaryAddress] > 0,
            "Beneficiary does not exist"
        );
        require(newShares > 0, "New shares must be greater than zero");

        uint256 currentShares = beneficiaryShares[beneficiaryAddress];
        uint256 newTotalShares = totalShares - currentShares + newShares;
        require(newTotalShares <= 10000, "Total shares would exceed 10000");

        beneficiaryShares[beneficiaryAddress] = newShares;
        totalShares = newTotalShares;

        emit BeneficiaryUpdated(beneficiaryAddress, newShares);
    }


    function getBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }


    function getBeneficiaryShares(address beneficiaryAddress)
        external
        view
        returns (uint256)
    {
        return beneficiaryShares[beneficiaryAddress];
    }


    function getTotalReceived() external view returns (uint256) {
        return totalReceived;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function getWithdrawnAmount(address beneficiaryAddress)
        external
        view
        returns (uint256)
    {
        return withdrawnAmounts[beneficiaryAddress];
    }


    function getOwner() external view returns (address) {
        return contractOwner;
    }


    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }
}
