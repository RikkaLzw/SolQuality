
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CrowdfundingPlatform is ReentrancyGuard, Ownable, Pausable {
    struct Campaign {
        address payable creator;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool fundsWithdrawn;
        string title;
        string description;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
    }

    uint256 public campaignCounter;
    uint256 public platformFeePercent = 250;
    uint256 public constant MAX_FEE_PERCENT = 1000;

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    mapping(uint256 => address[]) public campaignContributors;
    mapping(address => uint256[]) public userCampaigns;
    mapping(address => uint256[]) public userContributions;

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 goal,
        uint256 deadline,
        string title
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignCompleted(uint256 indexed campaignId, uint256 totalRaised);

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

    event PlatformFeeUpdated(uint256 newFeePercent);

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Invalid campaign ID");
        _;
    }

    modifier onlyCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Not campaign creator");
        _;
    }

    constructor() {}

    function createCampaign(
        uint256 _goal,
        uint256 _durationInDays,
        string memory _title,
        string memory _description
    ) external whenNotPaused returns (uint256) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");
        require(bytes(_title).length > 0, "Title cannot be empty");

        uint256 campaignId = campaignCounter;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            goal: _goal,
            raised: 0,
            deadline: deadline,
            completed: false,
            fundsWithdrawn: false,
            title: _title,
            description: _description
        });

        userCampaigns[msg.sender].push(campaignId);
        campaignCounter++;

        emit CampaignCreated(campaignId, msg.sender, _goal, deadline, _title);
        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        whenNotPaused
        nonReentrant
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(!campaign.completed, "Campaign already completed");


        uint256 currentContribution = contributions[_campaignId][msg.sender];
        uint256 newTotal = campaign.raised + msg.value;


        campaign.raised = newTotal;
        contributions[_campaignId][msg.sender] = currentContribution + msg.value;


        if (currentContribution == 0) {
            campaignContributors[_campaignId].push(msg.sender);
            userContributions[msg.sender].push(_campaignId);
        }


        if (newTotal >= campaign.goal && !campaign.completed) {
            campaign.completed = true;
            emit CampaignCompleted(_campaignId, newTotal);
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.completed || block.timestamp >= campaign.deadline, "Campaign not ended");
        require(campaign.raised >= campaign.goal, "Goal not reached");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");

        campaign.fundsWithdrawn = true;

        uint256 totalRaised = campaign.raised;
        uint256 platformFee = (totalRaised * platformFeePercent) / 10000;
        uint256 creatorAmount = totalRaised - platformFee;


        campaign.creator.transfer(creatorAmount);


        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount, platformFee);
    }

    function requestRefund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raised < campaign.goal, "Goal was reached");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");

        uint256 contributionAmount = contributions[_campaignId][msg.sender];
        require(contributionAmount > 0, "No contribution found");

        contributions[_campaignId][msg.sender] = 0;
        campaign.raised -= contributionAmount;

        payable(msg.sender).transfer(contributionAmount);

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);
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
            bool completed,
            bool fundsWithdrawn,
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
            campaign.completed,
            campaign.fundsWithdrawn,
            campaign.title,
            campaign.description
        );
    }

    function getCampaignContributors(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (address[] memory)
    {
        return campaignContributors[_campaignId];
    }

    function getUserCampaigns(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userCampaigns[_user];
    }

    function getUserContributions(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userContributions[_user];
    }

    function getContributionAmount(uint256 _campaignId, address _contributor)
        external
        view
        validCampaign(_campaignId)
        returns (uint256)
    {
        return contributions[_campaignId][_contributor];
    }

    function setCampaignCompleted(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.completed, "Already completed");
        require(campaign.raised >= campaign.goal, "Goal not reached");

        campaign.completed = true;
        emit CampaignCompleted(_campaignId, campaign.raised);
    }

    function setPlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= MAX_FEE_PERCENT, "Fee too high");
        platformFeePercent = _newFeePercent;
        emit PlatformFeeUpdated(_newFeePercent);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not accepted");
    }
}
