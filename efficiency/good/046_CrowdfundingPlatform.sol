
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    enum CampaignStatus { Active, Successful, Failed, Cancelled }

    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        CampaignStatus status;
        uint256 contributorCount;
    }

    struct Contribution {
        uint256 amount;
        uint256 timestamp;
    }


    uint256 public campaignCounter;
    uint256 public platformFeePercent = 250;
    uint256 public constant MAX_FEE_PERCENT = 1000;


    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => Contribution)) public contributions;
    mapping(address => uint256[]) public creatorCampaigns;
    mapping(address => uint256[]) public contributorCampaigns;


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
        uint256 amount
    );

    event CampaignStatusUpdated(
        uint256 indexed campaignId,
        CampaignStatus status
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Not campaign creator");
        _;
    }

    constructor() {}

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");

        uint256 campaignId = campaignCounter++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns[campaignId] = Campaign({
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: deadline,
            status: CampaignStatus.Active,
            contributorCount: 0
        });

        creatorCampaigns[msg.sender].push(campaignId);

        emit CampaignCreated(campaignId, msg.sender, _title, _goal, deadline);

        return campaignId;
    }

    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        nonReentrant
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Active, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign deadline passed");


        uint256 currentRaised = campaign.raised;
        bool isNewContributor = contributions[_campaignId][msg.sender].amount == 0;


        contributions[_campaignId][msg.sender].amount += msg.value;
        contributions[_campaignId][msg.sender].timestamp = block.timestamp;


        campaign.raised = currentRaised + msg.value;

        if (isNewContributor) {
            campaign.contributorCount++;
            contributorCampaigns[msg.sender].push(_campaignId);
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);


        if (campaign.raised >= campaign.goal) {
            campaign.status = CampaignStatus.Successful;
            emit CampaignStatusUpdated(_campaignId, CampaignStatus.Successful);
        }
    }

    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            campaign.status == CampaignStatus.Successful ||
            (block.timestamp >= campaign.deadline && campaign.raised >= campaign.goal),
            "Cannot withdraw funds"
        );

        uint256 totalRaised = campaign.raised;
        require(totalRaised > 0, "No funds to withdraw");


        uint256 platformFee = (totalRaised * platformFeePercent) / 10000;
        uint256 creatorAmount = totalRaised - platformFee;


        campaign.raised = 0;
        campaign.status = CampaignStatus.Successful;


        if (platformFee > 0) {
            payable(owner()).transfer(platformFee);
        }
        campaign.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }

    function refund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            block.timestamp >= campaign.deadline &&
            campaign.raised < campaign.goal,
            "Refund not available"
        );

        uint256 contributionAmount = contributions[_campaignId][msg.sender].amount;
        require(contributionAmount > 0, "No contribution found");


        contributions[_campaignId][msg.sender].amount = 0;


        if (campaign.status != CampaignStatus.Failed) {
            campaign.status = CampaignStatus.Failed;
            emit CampaignStatusUpdated(_campaignId, CampaignStatus.Failed);
        }

        payable(msg.sender).transfer(contributionAmount);

        emit RefundIssued(_campaignId, msg.sender, contributionAmount);
    }

    function cancelCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Active, "Campaign not active");
        require(campaign.raised == 0, "Cannot cancel campaign with contributions");

        campaign.status = CampaignStatus.Cancelled;
        emit CampaignStatusUpdated(_campaignId, CampaignStatus.Cancelled);
    }

    function updatePlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= MAX_FEE_PERCENT, "Fee too high");
        platformFeePercent = _newFeePercent;
    }


    function getCampaign(uint256 _campaignId)
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
            CampaignStatus status,
            uint256 contributorCount
        )
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.status,
            campaign.contributorCount
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        external
        view
        validCampaign(_campaignId)
        returns (uint256 amount, uint256 timestamp)
    {
        Contribution memory contribution = contributions[_campaignId][_contributor];
        return (contribution.amount, contribution.timestamp);
    }

    function getCreatorCampaigns(address _creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorCampaigns[_creator];
    }

    function getContributorCampaigns(address _contributor)
        external
        view
        returns (uint256[] memory)
    {
        return contributorCampaigns[_contributor];
    }

    function getCampaignProgress(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (uint256 percentFunded, uint256 timeRemaining)
    {
        Campaign memory campaign = campaigns[_campaignId];
        percentFunded = (campaign.raised * 100) / campaign.goal;
        timeRemaining = block.timestamp >= campaign.deadline ?
            0 : campaign.deadline - block.timestamp;
    }

    function getTotalCampaigns() external view returns (uint256) {
        return campaignCounter;
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {
        revert("Direct payments not accepted");
    }
}
