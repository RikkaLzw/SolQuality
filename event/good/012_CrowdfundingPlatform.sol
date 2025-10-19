
pragma solidity ^0.8.0;

contract CrowdfundingPlatform {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeePercentage = 250;
    address public platformOwner;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
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
        bool indexed goalReached,
        uint256 totalRaised
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
        uint256 oldFeePercentage,
        uint256 newFeePercentage
    );

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this function");
        _;
    }

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline has passed");
        _;
    }

    constructor() {
        platformOwner = msg.sender;
    }

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(bytes(_title).length > 0, "Campaign title cannot be empty");
        require(bytes(_description).length > 0, "Campaign description cannot be empty");
        require(_goalAmount > 0, "Goal amount must be greater than zero");
        require(_durationInDays > 0 && _durationInDays <= 365, "Duration must be between 1 and 365 days");

        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        uint256 campaignId = campaignCounter;

        Campaign storage newCampaign = campaigns[campaignId];
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.deadline = deadline;
        newCampaign.isActive = true;

        campaignCounter++;

        emit CampaignCreated(campaignId, msg.sender, _title, _goalAmount, deadline);
    }

    function contribute(uint256 _campaignId)
        external
        payable
        campaignExists(_campaignId)
        campaignActive(_campaignId)
    {
        require(msg.value > 0, "Contribution amount must be greater than zero");

        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender != campaign.creator, "Campaign creator cannot contribute to their own campaign");


        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;


        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value, campaign.raisedAmount);
    }

    function finalizeCampaign(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.isActive, "Campaign is already finalized");
        require(
            block.timestamp >= campaign.deadline || campaign.goalReached,
            "Campaign cannot be finalized yet"
        );

        campaign.isActive = false;

        emit CampaignCompleted(_campaignId, campaign.goalReached, campaign.raisedAmount);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only campaign creator can withdraw funds");
        require(!campaign.isActive, "Campaign must be finalized first");
        require(campaign.goalReached, "Campaign goal was not reached");
        require(campaign.raisedAmount > 0, "No funds to withdraw");

        uint256 totalAmount = campaign.raisedAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 10000;
        uint256 creatorAmount = totalAmount - platformFee;

        campaign.raisedAmount = 0;


        (bool creatorSuccess, ) = campaign.creator.call{value: creatorAmount}("");
        require(creatorSuccess, "Failed to transfer funds to creator");


        if (platformFee > 0) {
            (bool platformSuccess, ) = payable(platformOwner).call{value: platformFee}("");
            require(platformSuccess, "Failed to transfer platform fee");
        }

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount, platformFee);
    }

    function requestRefund(uint256 _campaignId)
        external
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.isActive, "Campaign must be finalized first");
        require(!campaign.goalReached, "Cannot refund successful campaign");

        uint256 contributionAmount = campaign.contributions[msg.sender];
        require(contributionAmount > 0, "No contribution found for this address");

        campaign.contributions[msg.sender] = 0;
        campaign.raisedAmount -= contributionAmount;

        (bool success, ) = payable(msg.sender).call{value: contributionAmount}("");
        require(success, "Failed to transfer refund");

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);
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

    function getCampaignDetails(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached,
            uint256 contributorCount
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached,
            campaign.contributors.length
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getCampaignContributors(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (address[] memory)
    {
        return campaigns[_campaignId].contributors;
    }

    function getActiveCampaigns()
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory activeCampaigns = new uint256[](campaignCounter);
        uint256 activeCount = 0;

        for (uint256 i = 0; i < campaignCounter; i++) {
            if (campaigns[i].isActive && block.timestamp < campaigns[i].deadline) {
                activeCampaigns[activeCount] = i;
                activeCount++;
            }
        }


        uint256[] memory result = new uint256[](activeCount);
        for (uint256 i = 0; i < activeCount; i++) {
            result[i] = activeCampaigns[i];
        }

        return result;
    }

    receive() external payable {
        revert("Direct payments not accepted. Use contribute function");
    }

    fallback() external payable {
        revert("Function not found. Check function signature");
    }
}
