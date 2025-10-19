
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
        uint256 raisedAmount;
        uint256 deadline;
        ProjectStatus status;
        bool exists;
    }


    struct Investment {
        address investor;
        uint256 amount;
        uint256 timestamp;
        bool refunded;
    }


    uint256 private nextProjectId;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => Investment[]) public projectInvestments;
    mapping(uint256 => mapping(address => uint256)) public investorAmounts;
    mapping(address => uint256[]) public creatorProjects;
    mapping(address => uint256[]) public investorProjects;

    uint256 public constant MINIMUM_TARGET_AMOUNT = 0.01 ether;
    uint256 public constant MINIMUM_INVESTMENT = 0.001 ether;
    uint256 public constant MAXIMUM_DURATION = 365 days;
    uint256 public constant PLATFORM_FEE_RATE = 25;

    address payable public platformOwner;
    uint256 public totalPlatformFees;


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
        uint256 newTotalAmount
    );

    event ProjectSuccessful(
        uint256 indexed projectId,
        uint256 totalRaised
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

    event ProjectStatusChanged(
        uint256 indexed projectId,
        ProjectStatus newStatus
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

    modifier projectActive(uint256 _projectId) {
        require(projects[_projectId].status == ProjectStatus.Active, "Project is not active");
        _;
    }

    modifier projectNotExpired(uint256 _projectId) {
        require(block.timestamp <= projects[_projectId].deadline, "Project has expired");
        _;
    }


    constructor() {
        platformOwner = payable(msg.sender);
        nextProjectId = 1;
    }


    function createProject(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external returns (uint256) {

        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_targetAmount >= MINIMUM_TARGET_AMOUNT, "Target amount too low");
        require(_durationInDays > 0 && _durationInDays * 1 days <= MAXIMUM_DURATION, "Invalid duration");

        uint256 projectId = nextProjectId;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);


        projects[projectId] = Project({
            projectId: projectId,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            deadline: deadline,
            status: ProjectStatus.Active,
            exists: true
        });


        creatorProjects[msg.sender].push(projectId);


        nextProjectId++;

        emit ProjectCreated(projectId, msg.sender, _title, _targetAmount, deadline);

        return projectId;
    }


    function investInProject(uint256 _projectId)
        external
        payable
        projectExists(_projectId)
        projectActive(_projectId)
        projectNotExpired(_projectId)
    {
        require(msg.value >= MINIMUM_INVESTMENT, "Investment amount too low");
        require(msg.sender != projects[_projectId].creator, "Creator cannot invest in own project");

        Project storage project = projects[_projectId];


        Investment memory newInvestment = Investment({
            investor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            refunded: false
        });

        projectInvestments[_projectId].push(newInvestment);
        investorAmounts[_projectId][msg.sender] += msg.value;
        project.raisedAmount += msg.value;


        bool alreadyInvested = false;
        uint256[] storage investorProjectList = investorProjects[msg.sender];
        for (uint256 i = 0; i < investorProjectList.length; i++) {
            if (investorProjectList[i] == _projectId) {
                alreadyInvested = true;
                break;
            }
        }
        if (!alreadyInvested) {
            investorProjects[msg.sender].push(_projectId);
        }

        emit InvestmentMade(_projectId, msg.sender, msg.value, project.raisedAmount);


        if (project.raisedAmount >= project.targetAmount) {
            project.status = ProjectStatus.Successful;
            emit ProjectSuccessful(_projectId, project.raisedAmount);
            emit ProjectStatusChanged(_projectId, ProjectStatus.Successful);
        }
    }


    function withdrawFunds(uint256 _projectId)
        external
        projectExists(_projectId)
        onlyProjectCreator(_projectId)
    {
        Project storage project = projects[_projectId];
        require(project.status == ProjectStatus.Successful, "Project must be successful to withdraw");
        require(project.status != ProjectStatus.Withdrawn, "Funds already withdrawn");

        uint256 totalAmount = project.raisedAmount;
        uint256 platformFee = (totalAmount * PLATFORM_FEE_RATE) / 1000;
        uint256 creatorAmount = totalAmount - platformFee;


        project.status = ProjectStatus.Withdrawn;
        totalPlatformFees += platformFee;


        project.creator.transfer(creatorAmount);

        emit FundsWithdrawn(_projectId, project.creator, creatorAmount, platformFee);
        emit ProjectStatusChanged(_projectId, ProjectStatus.Withdrawn);
    }


    function requestRefund(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];


        if (block.timestamp > project.deadline && project.status == ProjectStatus.Active) {
            project.status = ProjectStatus.Failed;
            emit ProjectStatusChanged(_projectId, ProjectStatus.Failed);
        }

        require(project.status == ProjectStatus.Failed, "Refund only available for failed projects");

        uint256 investmentAmount = investorAmounts[_projectId][msg.sender];
        require(investmentAmount > 0, "No investment found for this investor");


        Investment[] storage investments = projectInvestments[_projectId];
        for (uint256 i = 0; i < investments.length; i++) {
            if (investments[i].investor == msg.sender && !investments[i].refunded) {
                investments[i].refunded = true;
            }
        }


        investorAmounts[_projectId][msg.sender] = 0;


        payable(msg.sender).transfer(investmentAmount);

        emit RefundIssued(_projectId, msg.sender, investmentAmount);
    }


    function updateProjectStatus(uint256 _projectId)
        external
        projectExists(_projectId)
    {
        Project storage project = projects[_projectId];

        if (block.timestamp > project.deadline && project.status == ProjectStatus.Active) {
            if (project.raisedAmount >= project.targetAmount) {
                project.status = ProjectStatus.Successful;
                emit ProjectSuccessful(_projectId, project.raisedAmount);
            } else {
                project.status = ProjectStatus.Failed;
            }
            emit ProjectStatusChanged(_projectId, project.status);
        }
    }


    function withdrawPlatformFees() external onlyPlatformOwner {
        require(totalPlatformFees > 0, "No fees to withdraw");

        uint256 amount = totalPlatformFees;
        totalPlatformFees = 0;

        platformOwner.transfer(amount);
    }


    function getProject(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (Project memory)
    {
        return projects[_projectId];
    }


    function getInvestmentCount(uint256 _projectId)
        external
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return projectInvestments[_projectId].length;
    }


    function getInvestment(uint256 _projectId, uint256 _index)
        external
        view
        projectExists(_projectId)
        returns (Investment memory)
    {
        require(_index < projectInvestments[_projectId].length, "Investment index out of bounds");
        return projectInvestments[_projectId][_index];
    }


    function getCreatorProjects(address _creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorProjects[_creator];
    }


    function getInvestorProjects(address _investor)
        external
        view
        returns (uint256[] memory)
    {
        return investorProjects[_investor];
    }


    function getTotalProjects() external view returns (uint256) {
        return nextProjectId - 1;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    bool public emergencyPaused = false;

    modifier whenNotPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }

    function toggleEmergencyPause() external onlyPlatformOwner {
        emergencyPaused = !emergencyPaused;
    }
}
