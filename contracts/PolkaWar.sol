// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReentrancyGuard.sol";

contract PolkaWar is Ownable, ReentrancyGuard {

    IERC20 public polkaWarToken;
    uint256 public rewardMultiplier;
    enum GameState { Opening, Waiting, Running, Finished }

    constructor(address _tokenAddress) {
        polkaWarToken = IERC20(_tokenAddress);
        rewardMultiplier = 90;
    }

    struct GamePool {
        uint256 id;
        GameState state;
        uint256 tokenAmount; // token amount needed to enter each pool
        address[] player;
        address winner;
        bool drawStatus;
    }

    GamePool[] public pools;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event LogClaimAward(uint256 indexed pid, address indexed winnerAddress, uint256 award);

    // get number of games
    function poolLength() external view returns (uint256) {
        return pools.length;
    }

    // add pool
    function addPool(
        uint256 _tokenAmount
    ) external onlyOwner {
        pools.push(
            GamePool({
                id : pools.length + 1,
                state : GameState.Opening,
                tokenAmount : _tokenAmount,
                player : new address[](0),
                winner : address(0),
                drawStatus: false
            })
        );
    }

    // update pool
    function updatePool(
        uint256 _pid,
        uint256 _tokenAmount
    ) external onlyOwner {
        uint256 poolIndex = _pid - 1;
        if(_tokenAmount > 0) {
            pools[poolIndex].tokenAmount = _tokenAmount;
        }
    }

    // bet game
    function bet(uint256 _pid) external {
        uint256 poolIndex = _pid - 1;
        // check balance
        require(polkaWarToken.balanceOf(msg.sender) >= pools[poolIndex].tokenAmount, "insufficient funds");
        // check game status
        require(pools[poolIndex].state != GameState.Running, "game is running");
        // add user
        if(pools[poolIndex].state == GameState.Opening) {
            pools[poolIndex].player.push(msg.sender);
            pools[poolIndex].state = GameState.Waiting;
        } else if(pools[poolIndex].state == GameState.Waiting) {
            pools[poolIndex].player.push(msg.sender);
            pools[poolIndex].state = GameState.Running;
        }
        // deposit token
        polkaWarToken.transferFrom(msg.sender, address(this), pools[poolIndex].tokenAmount);
        emit Transfer(msg.sender, address(this), pools[poolIndex].tokenAmount);
    }

    // get game players
    function getGamePlayers(uint256 pid) external view returns (address[] memory) {
        return pools[pid - 1].player;        
    }

    // update game status
    function updateGameStatus(uint256 _pid, address _winnerAddress, bool drawStatus) external onlyOwner {
        uint256 poolIndex = _pid - 1;
        // check game status
        require(pools[poolIndex].state == GameState.Running, "no valid time");
        if(drawStatus == true) {
            // set draw status to true
            pools[poolIndex].drawStatus = true;
        } else {
            // check winner in players
            require(pools[poolIndex].player[0] == _winnerAddress || pools[poolIndex].player[1] == _winnerAddress, "player not found");
            // set winner
            pools[poolIndex].winner = _winnerAddress;
        }
        // update game state
        pools[poolIndex].state = GameState.Finished;
    }

    // claim award
    function claimAward(uint256 _pid) external nonReentrant {
        uint256 poolIndex = _pid - 1;
        // check game status
        require(pools[poolIndex].state == GameState.Finished, "no valid time");
        require(pools[poolIndex].player[0] == msg.sender || pools[poolIndex].player[1] == msg.sender, "player not found");
        if(pools[poolIndex].drawStatus == true) {
            uint256 refund = pools[poolIndex].tokenAmount * rewardMultiplier / 100;
            polkaWarToken.transfer(msg.sender, refund);
            emit LogClaimAward(_pid, msg.sender, refund);
        } else {
            require(pools[poolIndex].winner == msg.sender, "not winner");
            // send award
            uint256 award = pools[poolIndex].tokenAmount * 2 * rewardMultiplier / 100;
            uint256 gasFee = pools[poolIndex].tokenAmount * 2 * (100 - rewardMultiplier) / 100;
            polkaWarToken.transfer(msg.sender, award);
            polkaWarToken.transfer(owner(), gasFee);
            emit LogClaimAward(_pid, msg.sender, award);
        }
        // initialize game
        pools[poolIndex].state = GameState.Opening;
        pools[poolIndex].winner = address(0);
        pools[poolIndex].player = new address[](0);
        pools[poolIndex].drawStatus = false;
    }

    // withdraw funds
    function withdrawFund() external onlyOwner {
        uint256 balance = polkaWarToken.balanceOf(address(this));
        require(balance > 0, "not enough fund");
        polkaWarToken.transfer(msg.sender, balance);
    }
}