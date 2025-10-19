
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 amountRaised;
        bool withdrawn;
        bool exists;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) public campaignContributors;

    uint256 public nextCampaignId;
    uint256 public platformFeePercentage = 250;
    address payable public platformOwner;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 totalRaised
    );

    event CampaignGoalReached(
        uint256 indexed campaignId,
        uint256 totalRaised,
        uint256 timestamp
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event PlatformFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(campaigns[_campaignId].exists, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has ended");
        _;
    }

    modifier campaignEnded(uint256 _campaignId) {
        require(block.timestamp >= campaigns[_campaignId].deadline, "Campaign is still active");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Only campaign creator can call this function");
        _;
    }

    constructor() {
        platformOwner = payable(msg.sender);
        nextCampaignId = 1;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Campaign title cannot be empty");
        require(bytes(_description).length > 0, "Campaign description cannot be empty");
        require(_goal > 0, "Campaign goal must be greater than zero");
        require(_durationInDays > 0 && _durationInDays <= 365, "Campaign duration must be between 1 and 365 days");

        uint256 campaignId = nextCampaignId;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            deadline: deadline,
            amountRaised: 0,
            withdrawn: false,
            exists: true
        });

        nextCampaignId++;

        emit CampaignCreated(campaignId, msg.sender, _title, _goal, deadline);

        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        campaignExists(_campaignId)
        campaignActive(_campaignId)
    {
        require(msg.value > 0, "Contribution amount must be greater than zero");

        Campaign storage campaign = campaigns[_campaignId];


        if (contributions[_campaignId][msg.sender].amount == 0) {
            campaignContributors[_campaignId].push(msg.sender);
        }

        contributions[_campaignId][msg.sender].amount += msg.value;
        contributions[_campaignId][msg.sender].timestamp = block.timestamp;

        campaign.amountRaised += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value, campaign.amountRaised);


        if (campaign.amountRaised >= campaign.goal) {
            emit CampaignGoalReached(_campaignId, campaign.amountRaised, block.timestamp);
        }
    }

    function withdrawFunds(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        campaignEnded(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.amountRaised >= campaign.goal, "Campaign goal was not reached");
        require(!campaign.withdrawn, "Funds have already been withdrawn");
        require(campaign.amountRaised > 0, "No funds to withdraw");

        campaign.withdrawn = true;

        uint256 platformFee = (campaign.amountRaised * platformFeePercentage) / 10000;
        uint256 creatorAmount = campaign.amountRaised - platformFee;


        if (platformFee > 0) {
            (bool feeSuccess, ) = platformOwner.call{value: platformFee}("");
            require(feeSuccess, "Platform fee transfer failed");
        }


        (bool success, ) = campaign.creator.call{value: creatorAmount}("");
        require(success, "Fund transfer to creator failed");

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount, platformFee);
    }

    function requestRefund(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.amountRaised < campaign.goal, "Campaign goal was reached, no refunds available");
        require(!campaign.withdrawn, "Funds have already been withdrawn");

        uint256 contributionAmount = contributions[_campaignId][msg.sender].amount;
        require(contributionAmount > 0, "No contribution found for this address");


        contributions[_campaignId][msg.sender].amount = 0;
        campaign.amountRaised -= contributionAmount;


        (bool success, ) = payable(msg.sender).call{value: contributionAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 deadline,
            uint256 amountRaised,
            bool withdrawn,
            bool isActive,
            bool goalReached
        )
    {
        Campaign storage campaign = campaigns[_campaignId];

        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.deadline,
            campaign.amountRaised,
            campaign.withdrawn,
            block.timestamp < campaign.deadline,
            campaign.amountRaised >= campaign.goal
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        campaignExists(_campaignId)
        returns (uint256 amount, uint256 timestamp)
    {
        Contribution storage contribution = contributions[_campaignId][_contributor];
        return (contribution.amount, contribution.timestamp);
    }

    function getCampaignContributors(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (address[] memory)
    {
        return campaignContributors[_campaignId];
    }

    function updatePlatformFee(uint256 _newFeePercentage)
        external
        onlyPlatformOwner
    {
        require(_newFeePercentage <= 1000, "Platform fee cannot exceed 10%");

        uint256 oldFee = platformFeePercentage;
        platformFeePercentage = _newFeePercentage;

        emit PlatformFeeUpdated(oldFee, _newFeePercentage);
    }

    function transferPlatformOwnership(address payable _newOwner)
        external
        onlyPlatformOwner
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        platformOwner = _newOwner;
    }


    function emergencyWithdraw(uint256 _campaignId)
        external
        onlyPlatformOwner
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp > campaign.deadline + 365 days, "Emergency withdrawal only available after 1 year past deadline");
        require(campaign.amountRaised < campaign.goal, "Cannot emergency withdraw from successful campaigns");
        require(!campaign.withdrawn, "Funds already withdrawn");

        campaign.withdrawn = true;

        (bool success, ) = platformOwner.call{value: campaign.amountRaised}("");
        require(success, "Emergency withdrawal failed");
    }

    receive() external payable {
        revert("Direct payments not accepted. Use contribute function");
    }

    fallback() external payable {
        revert("Function not found. Use contribute function to make contributions");
    }
}
