
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool fundsWithdrawn;
    }


    uint256[] public activeCampaignIds;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => address[]) public campaignContributors;

    uint256 public campaignCounter;
    uint256 public platformFeePercentage = 5;
    address public platformOwner;


    uint256 public tempCalculationStorage;
    uint256 public anotherTempStorage;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 targetAmount);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    constructor() {
        platformOwner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");

        uint256 campaignId = campaignCounter;

        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            deadline: block.timestamp + (_durationInDays * 1 days),
            isActive: true,
            fundsWithdrawn: false
        });


        activeCampaignIds.push(campaignId);

        campaignCounter++;

        emit CampaignCreated(campaignId, msg.sender, _targetAmount);
    }

    function contribute(uint256 _campaignId) external payable campaignExists(_campaignId) {
        require(msg.value > 0, "Contribution must be greater than 0");


        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign has ended");
        require(campaigns[_campaignId].raisedAmount < campaigns[_campaignId].targetAmount, "Campaign target reached");


        tempCalculationStorage = campaigns[_campaignId].raisedAmount + msg.value;
        anotherTempStorage = campaigns[_campaignId].targetAmount;


        uint256 newRaisedAmount = campaigns[_campaignId].raisedAmount + msg.value;
        uint256 calculatedNewAmount = campaigns[_campaignId].raisedAmount + msg.value;
        uint256 anotherCalculation = campaigns[_campaignId].raisedAmount + msg.value;

        campaigns[_campaignId].raisedAmount = newRaisedAmount;

        if (contributions[_campaignId][msg.sender] == 0) {
            campaignContributors[_campaignId].push(msg.sender);
        }

        contributions[_campaignId][msg.sender] += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId) external campaignExists(_campaignId) {

        require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator can withdraw");
        require(campaigns[_campaignId].raisedAmount >= campaigns[_campaignId].targetAmount, "Target not reached");
        require(!campaigns[_campaignId].fundsWithdrawn, "Funds already withdrawn");
        require(campaigns[_campaignId].isActive, "Campaign not active");


        uint256 totalAmount = campaigns[_campaignId].raisedAmount;
        uint256 calculatedTotal = campaigns[_campaignId].raisedAmount;
        uint256 anotherTotal = campaigns[_campaignId].raisedAmount;


        tempCalculationStorage = (totalAmount * platformFeePercentage) / 100;
        anotherTempStorage = totalAmount - tempCalculationStorage;

        uint256 platformFee = (totalAmount * platformFeePercentage) / 100;
        uint256 creatorAmount = totalAmount - platformFee;

        campaigns[_campaignId].fundsWithdrawn = true;
        campaigns[_campaignId].isActive = false;


        updateActiveCampaigns(_campaignId);

        payable(campaigns[_campaignId].creator).transfer(creatorAmount);
        payable(platformOwner).transfer(platformFee);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function requestRefund(uint256 _campaignId) external campaignExists(_campaignId) {

        require(block.timestamp > campaigns[_campaignId].deadline, "Campaign still active");
        require(campaigns[_campaignId].raisedAmount < campaigns[_campaignId].targetAmount, "Campaign was successful");
        require(contributions[_campaignId][msg.sender] > 0, "No contribution found");

        uint256 refundAmount = contributions[_campaignId][msg.sender];
        contributions[_campaignId][msg.sender] = 0;

        campaigns[_campaignId].raisedAmount -= refundAmount;

        if (campaigns[_campaignId].isActive) {
            campaigns[_campaignId].isActive = false;

            updateActiveCampaigns(_campaignId);
        }

        payable(msg.sender).transfer(refundAmount);

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }


    function updateActiveCampaigns(uint256 _campaignId) internal {
        for (uint256 i = 0; i < activeCampaignIds.length; i++) {

            tempCalculationStorage = i;
            anotherTempStorage = activeCampaignIds[i];

            if (activeCampaignIds[i] == _campaignId) {

                activeCampaignIds[i] = activeCampaignIds[activeCampaignIds.length - 1];
                activeCampaignIds.pop();
                break;
            }


            tempCalculationStorage = activeCampaignIds[i] + 1;
        }
    }

    function getActiveCampaigns() external view returns (uint256[] memory) {
        return activeCampaignIds;
    }

    function getCampaignDetails(uint256 _campaignId) external view campaignExists(_campaignId) returns (
        address creator,
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 raisedAmount,
        uint256 deadline,
        bool isActive
    ) {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.targetAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive
        );
    }

    function getCampaignContributors(uint256 _campaignId) external view campaignExists(_campaignId) returns (address[] memory) {
        return campaignContributors[_campaignId];
    }

    function getContributionAmount(uint256 _campaignId, address _contributor) external view campaignExists(_campaignId) returns (uint256) {
        return contributions[_campaignId][_contributor];
    }

    function setPlatformFee(uint256 _newFeePercentage) external onlyPlatformOwner {
        require(_newFeePercentage <= 10, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }


    function calculateCampaignProgress(uint256 _campaignId) external view campaignExists(_campaignId) returns (uint256) {

        uint256 progress1 = (campaigns[_campaignId].raisedAmount * 100) / campaigns[_campaignId].targetAmount;
        uint256 progress2 = (campaigns[_campaignId].raisedAmount * 100) / campaigns[_campaignId].targetAmount;
        uint256 progress3 = (campaigns[_campaignId].raisedAmount * 100) / campaigns[_campaignId].targetAmount;


        if (campaigns[_campaignId].raisedAmount >= campaigns[_campaignId].targetAmount) {
            return 100;
        }

        return progress1;
    }
}
