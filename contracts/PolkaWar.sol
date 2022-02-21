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
        address[] players;
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
                players : new address[](0),
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
            pools[poolIndex].players.push(msg.sender);
            pools[poolIndex].state = GameState.Waiting;
        } else if(pools[poolIndex].state == GameState.Waiting) {
            pools[poolIndex].players.push(msg.sender);
            pools[poolIndex].state = GameState.Running;
        }
        // deposit token
        polkaWarToken.transferFrom(msg.sender, address(this), pools[poolIndex].tokenAmount);
        emit Transfer(msg.sender, address(this), pools[poolIndex].tokenAmount);
    }

    // get game players
    function getGamePlayers(uint256 _pid) public view returns (address[] memory) {
        uint256 poolIndex = _pid - 1;
        GamePool storage pool = pools[poolIndex];
        address[] memory players = pool.players;
        return players;        
    }

    // update game status
    function updateGameStatus(uint256 _pid, address _winnerAddress, bool drawStatus) external onlyOwner {
        uint256 poolIndex = _pid - 1;
        GamePool storage pool = pools[poolIndex];
        // check game status
        require(pool.state == GameState.Running, "no valid time");
        if(drawStatus == true) {
            // set draw status to true
            pool.drawStatus = true;
        } else {
            // check winner in players
            address[] memory players = pool.players;
            require(players[0] == _winnerAddress || players[1] == _winnerAddress, "player not found");
            // require(getGamePlayers(poolIndex)[0] == _winnerAddress || getGamePlayers(poolIndex)[1] == _winnerAddress, "player not found");
            // set winner
            pool.winner = _winnerAddress;
        }
        // update game state
        pool.state = GameState.Finished;
    }

    // draw
    function draw(uint256 _pid) external onlyOwner {
        uint256 poolIndex = _pid - 1;
        GamePool storage pool = pools[poolIndex];
        require(pool.state == GameState.Finished, "no valid time");
        uint256 refund = pool.tokenAmount * rewardMultiplier / 100;
        address[] memory players = pool.players;
        polkaWarToken.transfer(players[0], refund);
        polkaWarToken.transfer(players[1], refund);
        uint256 gasFee = pool.tokenAmount * 2 * (100 - rewardMultiplier) / 100;
        polkaWarToken.transfer(owner(), gasFee);
        emit LogClaimAward(_pid, msg.sender, refund);
        pool.state = GameState.Opening;
        pool.winner = address(0);
        pool.players = new address[](0);
        pool.drawStatus = false;
    }

    // claim award
    function claimAward(uint256 _pid) external nonReentrant {
        uint256 poolIndex = _pid - 1;
        GamePool storage pool = pools[poolIndex];
        // check game status
        require(pool.state == GameState.Finished, "no valid time");
        address[] memory players = pool.players;
        require(players[0] == msg.sender || players[1] == msg.sender, "player not found");
        // if(pools[poolIndex].drawStatus == true) {
        //     uint256 refund = pools[poolIndex].tokenAmount * rewardMultiplier / 100;
        //     polkaWarToken.transfer(msg.sender, refund);
        //     emit LogClaimAward(_pid, msg.sender, refund);
        // } else 
        {
            require(pool.winner == msg.sender, "not winner");
            // send award
            uint256 award = pool.tokenAmount * 2 * rewardMultiplier / 100;
            uint256 gasFee = pool.tokenAmount * 2 * (100 - rewardMultiplier) / 100;
            polkaWarToken.transfer(msg.sender, award);
            polkaWarToken.transfer(owner(), gasFee);
            emit LogClaimAward(_pid, msg.sender, award);
        }
        // initialize game
        pool.state = GameState.Opening;
        pool.winner = address(0);
        pool.players = new address[](0);
        pool.drawStatus = false;
    }

    // withdraw funds
    function withdrawFund() external onlyOwner {
        uint256 balance = polkaWarToken.balanceOf(address(this));
        require(balance > 0, "not enough fund");
        polkaWarToken.transfer(msg.sender, balance);
    }
}