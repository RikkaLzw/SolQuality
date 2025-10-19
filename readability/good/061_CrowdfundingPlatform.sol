
pragma solidity ^0.8.0;


contract CrowdfundingPlatform {


    enum ProjectStatus {
        Active,
        Successful,
        Failed,
        Withdrawn
    }


    struct Project {
        uint256 projectId;
        address payable creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 deadline;
        ProjectStatus status;
        bool exists;
    }


    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
    }


    uint256 private nextProjectId;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Investment[]) public projectInvestments;
    mapping(uint256 => mapping(address => uint256)) public investorContributions;
    mapping(address => uint256[]) public creatorProjects;
    mapping(address => uint256[]) public investorProjects;

    address public platformOwner;
    uint256 public platformFeePercentage;


    event ProjectCreated(
        uint256 indexed projectId,
        address indexed creator,
        string title,
        uint256 targetAmount,
        uint256 deadline
    );

    event InvestmentMade(
        uint256 indexed projectId,
        address indexed investor,
        uint256 amount,
        uint256 newCurrentAmount
    );

    event ProjectStatusUpdated(
        uint256 indexed projectId,
        ProjectStatus newStatus
    );

    event FundsWithdrawn(
        uint256 indexed projectId,
        address indexed creator,
        uint256 amount,
        uint256 platformFee
    );

    event RefundIssued(
        uint256 indexed projectId,
        address indexed investor,
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

    modifier projectExists(uint256 _projectId) {
        require(projects[_projectId].exists, "Project does not exist");
        _;
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(projects[_projectId].creator == msg.sender, "Only project creator can call this function");
        _;
    }

    modifier projectIsActive(uint256 _projectId) {
        require(projects[_projectId].status == ProjectStatus.Active, "Project is not active");
        _;
    }


    constructor(uint256 _platformFeePercentage) {
        require(_platformFeePercentage <= 100, "Platform fee cannot exceed 10%");
        platformOwner = msg.sender;
        platformFeePercentage = _platformFeePercentage;
        nextProjectId = 1;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external returns (uint256 projectId) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Duration must be between 1 and 365 days");

        projectId = nextProjectId;
        nextProjectId++;

        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        projects[projectId] = Project({
            projectId: projectId,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            currentAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            exists: true
        });

        creatorProjects[msg.sender].push(projectId);

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);

        return projectId;
    }


    function investInProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
        projectIsActive(_projectId)
    {
        require(msg.value > 0, "Investment amount must be greater than 0");
        require(block.timestamp <= projects[_projectId].deadline, "Project deadline has passed");
        require(msg.sender != projects[_projectId].creator, "Creator cannot invest in own project");

        Project storage project = projects[_projectId];


        if (investorContributions[_projectId][msg.sender] == 0) {
            investorProjects[msg.sender].push(_projectId);
        }

        investorContributions[_projectId][msg.sender] += msg.value;
        project.currentAmount += msg.value;

        projectInvestments[_projectId].push(Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.currentAmount);


        if (project.currentAmount >= project.targetAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectStatusUpdated(_projectId, ProjectStatus.Successful);
        }
    }


    function updateProjectStatus(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];

        if (project.status == ProjectStatus.Active && block.timestamp > project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
            }
            emit ProjectStatusUpdated(_projectId, project.status);
        }
    }


    function withdrawFunds(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp > project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
            }
        }

        require(project.status == ProjectStatus.Successful, "Project must be successful to withdraw funds");

        uint256 totalAmount = project.currentAmount;
        uint256 platformFee = (totalAmount * platformFeePercentage) / 1000;
        uint256 creatorAmount = totalAmount - platformFee;

        project.status = ProjectStatus.Withdrawn;
        project.currentAmount = 0;


        (bool creatorSuccess, ) = project.creator.call{value: creatorAmount}("");
        require(creatorSuccess, "Transfer to creator failed");


        if (platformFee > 0) {
            (bool platformSuccess, ) = payable(platformOwner).call{value: platformFee}("");
            require(platformSuccess, "Transfer to platform failed");
        }

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
        emit ProjectStatusUpdated(_projectId, ProjectStatus.Withdrawn);
    }


    function requestRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];


        if (project.status == ProjectStatus.Active && block.timestamp > project.deadline) {
            if (project.currentAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
            } else {
                project.status = ProjectStatus.Failed;
            }
        }

        require(project.status == ProjectStatus.Failed, "Refunds only available for failed projects");

        uint256 investmentAmount = investorContributions[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this investor");

        investorContributions[_projectId][msg.sender] = 0;
        project.currentAmount -= investmentAmount;

        (bool success, ) = payable(msg.sender).call{value: investmentAmount}("");
        require(success, "Refund transfer failed");

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Project memory project)
    {
        return projects[_projectId];
    }


    function getInvestmentCount(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (uint256 count)
    {
        return projectInvestments[_projectId].length;
    }


    function getInvestment(uint256 _projectId, uint256 _index)
        external
        view
        projectExists(_projectId)
        returns (Investment memory investment)
    {
        require(_index < projectInvestments[_projectId].length, "Investment index out of bounds");
        return projectInvestments[_projectId][_index];
    }


    function getCreatorProjects(address _creator)
        external
        view
        returns (uint256[] memory projectIds)
    {
        return creatorProjects[_creator];
    }


    function getInvestorProjects(address _investor)
        external
        view
        returns (uint256[] memory projectIds)
    {
        return investorProjects[_investor];
    }


    function getInvestorContribution(uint256 _projectId, address _investor)
        external
        view
        returns (uint256 amount)
    {
        return investorContributions[_projectId][_investor];
    }


    function updatePlatformFee(uint256 _newFeePercentage)
        external
        onlyPlatformOwner
    {
        require(_newFeePercentage <= 100, "Platform fee cannot exceed 10%");

        uint256 oldFee = platformFeePercentage;
        platformFeePercentage = _newFeePercentage;

        emit PlatformFeeUpdated(oldFee, _newFeePercentage);
    }


    function getTotalProjectCount() external view returns (uint256 count) {
        return nextProjectId - 1;
    }


    function canInvestInProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (bool canInvest)
    {
        Project memory project = projects[_projectId];
        return project.status == ProjectStatus.Active && block.timestamp <= project.deadline;
    }


    function emergencyWithdraw() external onlyPlatformOwner {
        (bool success, ) = payable(platformOwner).call{value: address(this).balance}("");
        require(success, "Emergency withdraw failed");
    }
}
