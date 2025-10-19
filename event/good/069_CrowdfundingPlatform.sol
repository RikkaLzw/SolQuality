
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool withdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeePercent = 5;
    address public owner;

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

    event CampaignCompleted(
        uint256 indexed campaignId,
        uint256 totalRaised,
        bool goalReached
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

    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only platform owner can call this function");
        _;
    }

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has ended");
        require(!campaigns[_campaignId].completed, "Campaign already completed");
        _;
    }

    modifier campaignEnded(uint256 _campaignId) {
        require(block.timestamp >= campaigns[_campaignId].deadline, "Campaign is still active");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external {
        require(bytes(_title).length > 0, "Campaign title cannot be empty");
        require(bytes(_description).length > 0, "Campaign description cannot be empty");
        require(_goal > 0, "Campaign goal must be greater than zero");
        require(_durationInDays > 0, "Campaign duration must be greater than zero");

        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        Campaign storage newCampaign = campaigns[campaignCounter];
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goal = _goal;
        newCampaign.deadline = deadline;
        newCampaign.raised = 0;
        newCampaign.completed = false;
        newCampaign.withdrawn = false;

        emit CampaignCreated(campaignCounter, msg.sender, _title, _goal, deadline);
        campaignCounter++;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        campaignActive(_campaignId)
    {
        require(msg.value > 0, "Contribution must be greater than zero");

        Campaign storage campaign = campaigns[_campaignId];


        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.contributions[msg.sender] += msg.value;
        campaign.raised += msg.value;

        emit ContributionMade(_campaignId, msg.sender, msg.value, campaign.raised);


        if (campaign.raised >= campaign.goal && !campaign.completed) {
            campaign.completed = true;
            emit CampaignCompleted(_campaignId, campaign.raised, true);
        }
    }

    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(msg.sender == campaign.creator, "Only campaign creator can withdraw funds");
        require(campaign.raised >= campaign.goal, "Campaign goal not reached");
        require(!campaign.withdrawn, "Funds already withdrawn");
        require(campaign.raised > 0, "No funds to withdraw");

        campaign.withdrawn = true;

        uint256 platformFee = (campaign.raised * platformFeePercent) / 100;
        uint256 creatorAmount = campaign.raised - platformFee;


        if (!campaign.completed) {
            campaign.completed = true;
            emit CampaignCompleted(_campaignId, campaign.raised, true);
        }

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount, platformFee);


        campaign.creator.transfer(creatorAmount);
        payable(owner).transfer(platformFee);
    }

    function requestRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(campaign.raised < campaign.goal, "Campaign goal was reached, no refunds available");
        require(campaign.contributions[msg.sender] > 0, "No contribution found for this address");
        require(!campaign.withdrawn, "Funds already withdrawn by creator");

        uint256 contributionAmount = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;
        campaign.raised -= contributionAmount;


        if (!campaign.completed) {
            campaign.completed = true;
            emit CampaignCompleted(_campaignId, campaign.raised, false);
        }

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);

        payable(msg.sender).transfer(contributionAmount);
    }

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 raised,
            uint256 deadline,
            bool completed,
            bool withdrawn
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed,
            campaign.withdrawn
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        validCampaign(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getCampaignContributors(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (address[] memory)
    {
        return campaigns[_campaignId].contributors;
    }

    function isCampaignActive(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (bool)
    {
        Campaign storage campaign = campaigns[_campaignId];
        return block.timestamp < campaign.deadline && !campaign.completed;
    }

    function setPlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 10, "Platform fee cannot exceed 10%");

        uint256 oldFee = platformFeePercent;
        platformFeePercent = _newFeePercent;

        emit PlatformFeeUpdated(oldFee, _newFeePercent);
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not accepted. Use contribute function.");
    }

    fallback() external payable {
        revert("Function not found. Please use the correct function signature.");
    }
}
