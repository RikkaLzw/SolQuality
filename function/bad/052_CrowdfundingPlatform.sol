
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
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    address public platformOwner;
    uint256 public platformFee = 25;

    event CampaignCreated(uint256 campaignId, address creator, uint256 targetAmount);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);

    constructor() {
        platformOwner = msg.sender;
    }




    function createCampaignAndSetupRewards(
        string memory title,
        string memory description,
        uint256 targetAmount,
        uint256 durationInDays,
        bool enableEarlyBird,
        uint256 earlyBirdBonus,
        string memory rewardTier1,
        string memory rewardTier2
    ) public {
        require(targetAmount > 0, "Target amount must be positive");
        require(durationInDays > 0, "Duration must be positive");

        uint256 campaignId = campaignCounter++;
        Campaign storage campaign = campaigns[campaignId];


        campaign.creator = msg.sender;
        campaign.title = title;
        campaign.description = description;
        campaign.targetAmount = targetAmount;
        campaign.deadline = block.timestamp + (durationInDays * 1 days);
        campaign.isActive = true;


        if (enableEarlyBird) {

            uint256 bonusAmount = (targetAmount * earlyBirdBonus) / 1000;

        }




        emit CampaignCreated(campaignId, msg.sender, targetAmount);
    }


    function calculatePlatformFee(uint256 amount) public pure returns (uint256) {
        return (amount * 25) / 1000;
    }


    function contributeAndProcessRewards(uint256 campaignId) public payable {
        Campaign storage campaign = campaigns[campaignId];

        require(campaign.isActive, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(msg.value > 0, "Contribution must be positive");


        if (campaign.contributions[msg.sender] == 0) {

            campaign.contributors.push(msg.sender);

            if (campaign.contributors.length <= 10) {

                if (msg.value >= 1 ether) {

                    if (campaign.raisedAmount < campaign.targetAmount / 2) {

                        uint256 bonus = msg.value / 20;
                        campaign.raisedAmount += msg.value + bonus;
                        campaign.contributions[msg.sender] += msg.value + bonus;
                    } else {

                        campaign.raisedAmount += msg.value;
                        campaign.contributions[msg.sender] += msg.value;
                    }
                } else {

                    campaign.raisedAmount += msg.value;
                    campaign.contributions[msg.sender] += msg.value;
                }
            } else {

                campaign.raisedAmount += msg.value;
                campaign.contributions[msg.sender] += msg.value;
            }
        } else {

            if (campaign.contributions[msg.sender] + msg.value >= 5 ether) {

                uint256 vipBonus = msg.value / 50;
                campaign.raisedAmount += msg.value + vipBonus;
                campaign.contributions[msg.sender] += msg.value + vipBonus;
            } else {

                campaign.raisedAmount += msg.value;
                campaign.contributions[msg.sender] += msg.value;
            }
        }

        emit ContributionMade(campaignId, msg.sender, msg.value);
    }

    function withdrawFunds(uint256 campaignId) public {
        Campaign storage campaign = campaigns[campaignId];

        require(msg.sender == campaign.creator, "Only creator can withdraw");
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raisedAmount >= campaign.targetAmount, "Target not reached");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");

        campaign.fundsWithdrawn = true;
        campaign.isActive = false;

        uint256 platformFeeAmount = calculatePlatformFee(campaign.raisedAmount);
        uint256 creatorAmount = campaign.raisedAmount - platformFeeAmount;

        payable(platformOwner).transfer(platformFeeAmount);
        payable(campaign.creator).transfer(creatorAmount);

        emit FundsWithdrawn(campaignId, creatorAmount);
    }

    function refund(uint256 campaignId) public {
        Campaign storage campaign = campaigns[campaignId];

        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(campaign.raisedAmount < campaign.targetAmount, "Campaign was successful");
        require(campaign.contributions[msg.sender] > 0, "No contribution found");

        uint256 refundAmount = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;

        payable(msg.sender).transfer(refundAmount);
    }

    function getCampaignInfo(uint256 campaignId) public view returns (
        address creator,
        string memory title,
        uint256 targetAmount,
        uint256 raisedAmount,
        uint256 deadline,
        bool isActive
    ) {
        Campaign storage campaign = campaigns[campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.targetAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive
        );
    }

    function getContribution(uint256 campaignId, address contributor) public view returns (uint256) {
        return campaigns[campaignId].contributions[contributor];
    }

    function getContributorCount(uint256 campaignId) public view returns (uint256) {
        return campaigns[campaignId].contributors.length;
    }
}
