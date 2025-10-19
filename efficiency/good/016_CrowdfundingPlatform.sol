
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool withdrawn;
        bool active;
        string title;
        string description;
    }

    struct Contribution {
        uint256 amount;
        bool refunded;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(uint256 => address[]) public contributors;

    uint256 public campaignCounter;
    uint256 public constant PLATFORM_FEE = 25;
    address payable public platformOwner;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignSuccessful(uint256 indexed campaignId, uint256 totalRaised);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    modifier onlyActiveCampaign(uint256 _campaignId) {
        require(campaigns[_campaignId].active, "Campaign not active");
        require(block.timestamp <= campaigns[_campaignId].deadline, "Campaign expired");
        _;
    }

    modifier onlyCreator(uint256 _campaignId) {
        require(msg.sender == campaigns[_campaignId].creator, "Not campaign creator");
        _;
    }

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    constructor() {
        platformOwner = payable(msg.sender);
    }

    function createCampaign(
        uint256 _goal,
        uint256 _duration,
        string memory _title,
        string memory _description
    ) external returns (uint256) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");

        uint256 campaignId = campaignCounter++;
        uint256 deadline = block.timestamp + _duration;

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            goal: _goal,
            raised: 0,
            deadline: deadline,
            withdrawn: false,
            active: true,
            title: _title,
            description: _description
        });

        emit CampaignCreated(campaignId, msg.sender, _goal, deadline);
        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        onlyActiveCampaign(_campaignId)
        validCampaign(_campaignId)
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        Contribution storage userContribution = contributions[_campaignId][msg.sender];


        uint256 currentRaised = campaign.raised;
        uint256 contributionAmount = msg.value;


        if (userContribution.amount == 0) {
            contributors[_campaignId].push(msg.sender);
        }

        userContribution.amount += contributionAmount;
        campaign.raised = currentRaised + contributionAmount;

        emit ContributionMade(_campaignId, msg.sender, contributionAmount);


        if (campaign.raised >= campaign.goal) {
            emit CampaignSuccessful(_campaignId, campaign.raised);
        }
    }

    function withdrawFunds(uint256 _campaignId)
        external
        onlyCreator(_campaignId)
        validCampaign(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(block.timestamp > campaign.deadline, "Campaign still active");
        require(campaign.raised >= campaign.goal, "Goal not reached");
        require(!campaign.withdrawn, "Funds already withdrawn");

        campaign.withdrawn = true;
        campaign.active = false;


        uint256 totalRaised = campaign.raised;
        uint256 platformFeeAmount = (totalRaised * PLATFORM_FEE) / 1000;
        uint256 creatorAmount = totalRaised - platformFeeAmount;


        if (platformFeeAmount > 0) {
            platformOwner.transfer(platformFeeAmount);
        }

        campaign.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }

    function requestRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        Contribution storage userContribution = contributions[_campaignId][msg.sender];

        require(block.timestamp > campaign.deadline, "Campaign still active");
        require(campaign.raised < campaign.goal, "Campaign was successful");
        require(userContribution.amount > 0, "No contribution found");
        require(!userContribution.refunded, "Already refunded");

        uint256 refundAmount = userContribution.amount;
        userContribution.refunded = true;

        payable(msg.sender).transfer(refundAmount);

        emit RefundIssued(_campaignId, msg.sender, refundAmount);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (
            address creator,
            uint256 goal,
            uint256 raised,
            uint256 deadline,
            bool withdrawn,
            bool active,
            string memory title,
            string memory description
        )
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.withdrawn,
            campaign.active,
            campaign.title,
            campaign.description
        );
    }

    function getUserContribution(uint256 _campaignId, address _user)
        external
        view
        validCampaign(_campaignId)
        returns (uint256 amount, bool refunded)
    {
        Contribution memory contribution = contributions[_campaignId][_user];
        return (contribution.amount, contribution.refunded);
    }

    function getContributorsCount(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (uint256)
    {
        return contributors[_campaignId].length;
    }

    function isCampaignSuccessful(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (bool)
    {
        Campaign memory campaign = campaigns[_campaignId];
        return campaign.raised >= campaign.goal;
    }

    function isCampaignActive(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (bool)
    {
        Campaign memory campaign = campaigns[_campaignId];
        return campaign.active && block.timestamp <= campaign.deadline;
    }

    function changePlatformOwner(address payable _newOwner) external {
        require(msg.sender == platformOwner, "Only platform owner");
        require(_newOwner != address(0), "Invalid address");
        platformOwner = _newOwner;
    }
}
