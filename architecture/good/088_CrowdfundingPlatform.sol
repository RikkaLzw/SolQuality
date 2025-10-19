
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract CrowdfundingPlatform is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant MIN_FUNDING_GOAL = 0.1 ether;
    uint256 public constant MAX_FUNDING_DURATION = 365 days;
    uint256 public constant MIN_FUNDING_DURATION = 1 days;


    enum CampaignStatus { Active, Successful, Failed, Cancelled }


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
    mapping(address => uint256[]) public creatorCampaigns;
    mapping(address => uint256[]) public contributorCampaigns;

    uint256 public campaignCounter;
    uint256 public totalPlatformFees;


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

    event CampaignSuccessful(uint256 indexed campaignId, uint256 totalRaised);
    event CampaignFailed(uint256 indexed campaignId);
    event CampaignCancelled(uint256 indexed campaignId);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event PlatformFeesWithdrawn(address indexed owner, uint256 amount);


    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }

    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Not campaign creator");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].status == CampaignStatus.Active, "Campaign not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline passed");
        _;
    }

    modifier campaignEnded(uint256 _campaignId) {
        require(
            block.timestamp >= campaigns[_campaignId].deadline ||
            campaigns[_campaignId].status != CampaignStatus.Active,
            "Campaign still active"
        );
        _;
    }

    constructor() {}


    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _duration
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_fundingGoal >= MIN_FUNDING_GOAL, "Funding goal too low");
        require(_duration >= MIN_FUNDING_DURATION && _duration <= MAX_FUNDING_DURATION, "Invalid duration");

        uint256 campaignId = campaignCounter++;
        Campaign storage newCampaign = campaigns[campaignId];

        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.fundingGoal = _fundingGoal;
        newCampaign.deadline = block.timestamp.add(_duration);
        newCampaign.status = CampaignStatus.Active;
        newCampaign.fundsWithdrawn = false;

        creatorCampaigns[msg.sender].push(campaignId);

        emit CampaignCreated(campaignId, msg.sender, _title, _fundingGoal, newCampaign.deadline);
        return campaignId;
    }


    function contribute(uint256 _campaignId)
        external
        payable
        validCampaign(_campaignId)
        campaignActive(_campaignId)
        nonReentrant
    {
        require(msg.value > 0, "Contribution must be greater than 0");

        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender != campaign.creator, "Creator cannot contribute to own campaign");


        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
            contributorCampaigns[msg.sender].push(_campaignId);
        }

        campaign.contributions[msg.sender] = campaign.contributions[msg.sender].add(msg.value);
        campaign.totalRaised = campaign.totalRaised.add(msg.value);

        emit ContributionMade(_campaignId, msg.sender, msg.value);


        if (campaign.totalRaised >= campaign.fundingGoal) {
            campaign.status = CampaignStatus.Successful;
            emit CampaignSuccessful(_campaignId, campaign.totalRaised);
        }
    }


    function finalizeCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        campaignEnded(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Active, "Campaign already finalized");

        if (campaign.totalRaised >= campaign.fundingGoal) {
            campaign.status = CampaignStatus.Successful;
            emit CampaignSuccessful(_campaignId, campaign.totalRaised);
        } else {
            campaign.status = CampaignStatus.Failed;
            emit CampaignFailed(_campaignId);
        }
    }


    function withdrawFunds(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Successful, "Campaign not successful");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");

        campaign.fundsWithdrawn = true;

        uint256 platformFee = campaign.totalRaised.mul(PLATFORM_FEE_RATE).div(10000);
        uint256 creatorAmount = campaign.totalRaised.sub(platformFee);

        totalPlatformFees = totalPlatformFees.add(platformFee);

        (bool success, ) = campaign.creator.call{value: creatorAmount}("");
        require(success, "Transfer to creator failed");

        emit FundsWithdrawn(_campaignId, creatorAmount);
    }


    function refund(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        nonReentrant
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(
            campaign.status == CampaignStatus.Failed || campaign.status == CampaignStatus.Cancelled,
            "Campaign not eligible for refund"
        );

        uint256 contributedAmount = campaign.contributions[msg.sender];
        require(contributedAmount > 0, "No contribution to refund");

        campaign.contributions[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: contributedAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_campaignId, msg.sender, contributedAmount);
    }


    function cancelCampaign(uint256 _campaignId)
        external
        validCampaign(_campaignId)
        onlyCampaignCreator(_campaignId)
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.status == CampaignStatus.Active, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Cannot cancel after deadline");

        campaign.status = CampaignStatus.Cancelled;
        emit CampaignCancelled(_campaignId);
    }


    function withdrawPlatformFees() external onlyOwner nonReentrant {
        require(totalPlatformFees > 0, "No fees to withdraw");

        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Platform fee withdrawal failed");

        emit PlatformFeesWithdrawn(owner(), amount);
    }


    function getCampaignDetails(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
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

    function getCampaignStatus(uint256 _campaignId)
        external
        view
        validCampaign(_campaignId)
        returns (CampaignStatus)
    {
        return campaigns[_campaignId].status;
    }
}
