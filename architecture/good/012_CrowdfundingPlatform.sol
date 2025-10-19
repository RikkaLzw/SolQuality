
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant PLATFORM_FEE_PERCENTAGE = 250;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MIN_CAMPAIGN_DURATION = 1 days;
    uint256 public constant MAX_CAMPAIGN_DURATION = 365 days;
    uint256 public constant MIN_FUNDING_GOAL = 0.01 ether;


    enum CampaignStatus {
        Active,
        Successful,
        Failed,
        Cancelled
    }


    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 totalRaised;
        uint256 deadline;
        CampaignStatus status;
        bool fundsWithdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }


    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public totalPlatformFees;

    mapping(address => uint256[]) public creatorCampaigns;
    mapping(address => uint256[]) public contributorCampaigns;


    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 fundingGoal,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignCancelled(uint256 indexed campaignId);

    event PlatformFeesWithdrawn(uint256 amount);


    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(
            campaigns[_campaignId].creator == msg.sender,
            "Only campaign creator can perform this action"
        );
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(
            campaigns[_campaignId].status == CampaignStatus.Active,
            "Campaign is not active"
        );
        require(
            block.timestamp < campaigns[_campaignId].deadline,
            "Campaign deadline has passed"
        );
        _;
    }

    modifier validContribution() {
        require(msg.value > 0, "Contribution must be greater than 0");
        _;
    }


    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _duration
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_fundingGoal >= MIN_FUNDING_GOAL, "Funding goal too low");
        require(
            _duration >= MIN_CAMPAIGN_DURATION && _duration <= MAX_CAMPAIGN_DURATION,
            "Invalid campaign duration"
        );

        uint256 campaignId = campaignCounter;
        Campaign storage newCampaign = campaigns[campaignId];

        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.fundingGoal = _fundingGoal;
        newCampaign.deadline = block.timestamp.add(_duration);
        newCampaign.status = CampaignStatus.Active;
        newCampaign.fundsWithdrawn = false;

        creatorCampaigns[msg.sender].push(campaignId);
        campaignCounter = campaignCounter.add(1);

        emit CampaignCreated(
            campaignId,
            msg.sender,
            _title,
            _fundingGoal,
            newCampaign.deadline
        );
    }


    function contribute(uint256 _campaignId)
        external
        payable
        nonReentrant
        campaignExists(_campaignId)
        campaignActive(_campaignId)
        validContribution
    {
        Campaign storage campaign = campaigns[_campaignId];


        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
            contributorCampaigns[msg.sender].push(_campaignId);
        }

        campaign.contributions[msg.sender] = campaign.contributions[msg.sender].add(msg.value);
        campaign.totalRaised = campaign.totalRaised.add(msg.value);

        emit ContributionMade(_campaignId, msg.sender, msg.value);


        if (campaign.totalRaised >= campaign.fundingGoal) {
            campaign.status = CampaignStatus.Successful;
        }
    }


    function withdrawFunds(uint256 _campaignId)
        external
        nonReentrant
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(!campaign.fundsWithdrawn, "Funds already withdrawn");
        require(
            campaign.status == CampaignStatus.Successful ||
            (block.timestamp >= campaign.deadline && campaign.totalRaised >= campaign.fundingGoal),
            "Campaign conditions not met for withdrawal"
        );


        if (campaign.status == CampaignStatus.Active && campaign.totalRaised >= campaign.fundingGoal) {
            campaign.status = CampaignStatus.Successful;
        }

        campaign.fundsWithdrawn = true;


        uint256 platformFee = campaign.totalRaised.mul(PLATFORM_FEE_PERCENTAGE).div(FEE_DENOMINATOR);
        uint256 creatorAmount = campaign.totalRaised.sub(platformFee);

        totalPlatformFees = totalPlatformFees.add(platformFee);


        (bool success, ) = campaign.creator.call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");

        emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
    }


    function claimRefund(uint256 _campaignId)
        external
        nonReentrant
        campaignExists(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];

        require(
            block.timestamp >= campaign.deadline || campaign.status == CampaignStatus.Cancelled,
            "Campaign still active"
        );
        require(
            campaign.totalRaised < campaign.fundingGoal || campaign.status == CampaignStatus.Cancelled,
            "Campaign was successful"
        );
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");

        uint256 contributionAmount = campaign.contributions[msg.sender];
        require(contributionAmount > 0, "No contribution found");


        if (campaign.status == CampaignStatus.Active) {
            campaign.status = CampaignStatus.Failed;
        }


        campaign.contributions[msg.sender] = 0;


        (bool success, ) = payable(msg.sender).call{value: contributionAmount}("");
        require(success, "Refund transfer failed");

        emit RefundClaimed(_campaignId, msg.sender, contributionAmount);
    }


    function cancelCampaign(uint256 _campaignId)
        external
        campaignExists(_campaignId)
        onlyCampaignCreator(_campaignId)
        campaignActive(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.totalRaised == 0, "Cannot cancel campaign with contributions");

        campaign.status = CampaignStatus.Cancelled;
        emit CampaignCancelled(_campaignId);
    }


    function withdrawPlatformFees() external onlyOwner {
        require(totalPlatformFees > 0, "No fees to withdraw");

        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Fee withdrawal failed");

        emit PlatformFeesWithdrawn(amount);
    }


    function getCampaignDetails(uint256 _campaignId)
        external
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 fundingGoal,
            uint256 totalRaised,
            uint256 deadline,
            CampaignStatus status,
            bool fundsWithdrawn
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.fundingGoal,
            campaign.totalRaised,
            campaign.deadline,
            campaign.status,
            campaign.fundsWithdrawn
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
}
