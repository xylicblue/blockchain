// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CropEscrow is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20 public stablecoin;

    struct Milestone {
        address farmer;
        address investor;
        uint256 amount;
        bool isFunded;
        bool isReleased;
    }

    // milestoneId => Milestone details
    mapping(bytes32 => Milestone) public milestones;

    event MilestoneFunded(bytes32 indexed milestoneId, address indexed investor, address indexed farmer, uint256 amount);
    event MilestoneReleased(bytes32 indexed milestoneId, address indexed farmer, uint256 amount);
    event MilestoneRefunded(bytes32 indexed milestoneId, address indexed investor, uint256 amount);

    constructor(address _stablecoinAddress) {
        require(_stablecoinAddress != address(0), "Invalid stablecoin address");
        stablecoin = IERC20(_stablecoinAddress);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        // The Oracle role will be granted later to the backend wallet address
    }

    /**
     * @dev Called by an investor to fund a milestone. 
     * Investor must have approved this contract to spend `_amount` of stablecoin.
     */
    function deposit(bytes32 _milestoneId, address _farmer, uint256 _amount) external nonReentrant {
        require(_farmer != address(0), "Invalid farmer address");
        require(_amount > 0, "Amount must be greater than zero");
        require(!milestones[_milestoneId].isFunded, "Milestone already funded");

        milestones[_milestoneId] = Milestone({
            farmer: _farmer,
            investor: msg.sender,
            amount: _amount,
            isFunded: true,
            isReleased: false
        });

        // Transfer funds from investor to escrow contract
        stablecoin.safeTransferFrom(msg.sender, address(this), _amount);

        emit MilestoneFunded(_milestoneId, msg.sender, _farmer, _amount);
    }

    /**
     * @dev Called by the off-chain oracle (compute-backend) when ML metrics show the crop is healthy.
     */
    function releasePayment(bytes32 _milestoneId) external onlyRole(ORACLE_ROLE) nonReentrant {
        Milestone storage milestone = milestones[_milestoneId];
        require(milestone.isFunded, "Milestone not funded");
        require(!milestone.isReleased, "Milestone already released");

        milestone.isReleased = true;

        // Transfer stablecoin to farmer
        stablecoin.safeTransfer(milestone.farmer, milestone.amount);

        emit MilestoneReleased(_milestoneId, milestone.farmer, milestone.amount);
    }

    /**
     * @dev Called by the admin in case of dispute or crop failure / cancellation. 
     * Funds are returned to the investor.
     */
    function refund(bytes32 _milestoneId) external onlyRole(ADMIN_ROLE) nonReentrant {
        Milestone storage milestone = milestones[_milestoneId];
        require(milestone.isFunded, "Milestone not funded");
        require(!milestone.isReleased, "Milestone already released");

        milestone.isReleased = true; // Mark as released to prevent double-refund

        // Transfer stablecoin back to investor
        stablecoin.safeTransfer(milestone.investor, milestone.amount);

        emit MilestoneRefunded(_milestoneId, milestone.investor, milestone.amount);
    }
}
