//
// A contract for selling pre-sale tokens
//
// Supports the "standardized token API" as described in https://github.com/ethereum/wiki/wiki/Standardized_Contract_APIs
//
// To create an escrow request call the create() method for setup
//
// The recipient can make a simple Ether transfer to get the tokens released to his address.
//
// The buyer pays all the fees (including gas).
//

pragma solidity ^0.4.0;

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

contract IToken {
  function balanceOf(address _address) constant returns (uint balance);
  function transfer(address _to, uint _value) returns (bool success);
}

contract TokenEscrow is usingOraclize {
  address owner;
  
  uint public ETH_TO_USD_CENT_EXCHANGE_RATE = 31736;
  event newOraclizeQuery(string description);

  modifier owneronly { if (msg.sender == owner) _; }
  
  function setOwner(address _owner) owneronly {
    owner = _owner;
  }
  
  struct TokenSupply {
	uint limit;
	uint totalSupply;
	uint priceInCentsPerToken;
  }
  
  TokenSupply[2] public tokenSupplies;

  function TokenEscrow() {
    owner = msg.sender;
	
	tokenSupplies[0] = TokenSupply(1000000, 0, 20);
	tokenSupplies[1] = TokenSupply(2000000, 0, 30);
	
	// FIXME: enable oraclize_setProof is production
    // oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    update(0);
  }

  struct Escrow {
    address token;           // address of the token contract
    address seller;          // seller's address
    address recipient;       // address to receive the tokens
  }

  mapping (address => Escrow) public escrows;

  function __callback(bytes32 myid, string result, bytes proof) {
    if (msg.sender != oraclize_cbAddress()) throw;
    
    ETH_TO_USD_CENT_EXCHANGE_RATE = parseInt(result, 2); // save it in storage as $ cents
    // update(60 * 60); // FIXME: comment this out to enable recursive price updates once in every hour
  }

  function update(uint delay) payable {
    if (oraclize_getPrice("URL") > this.balance) {
      newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
      newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
      oraclize_query(delay, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    }
  }
  
  function create(address token, address seller, address buyer, address recipient) owneronly {
    escrows[buyer] = Escrow(token, seller, recipient);
  }

  function create(address token, address seller, address buyer) owneronly {
    create(token, seller, buyer, buyer);
  }
  
  // Incoming transfer from the buyer
  function() payable {
    if (ETH_TO_USD_CENT_EXCHANGE_RATE == 0)
      throw;
    
    Escrow escrow = escrows[msg.sender];

    // Contract not set up
    if (escrow.token == 0)
      throw;

    IToken token = IToken(escrow.token);
    
	uint tokenAmount = 0;
	uint amountOfCentsToBePaid = 0;
	uint amountOfCentsTransfered = msg.value * ETH_TO_USD_CENT_EXCHANGE_RATE / 1 ether;
		
	for (uint discountIndex = 0; discountIndex < 2; discountIndex++) {
		  if (amountOfCentsTransfered <= 0) {
			  break;
		  }
		  TokenSupply tokenSupply = tokenSupplies[discountIndex];
		  uint tokensPossibleToBuy = (tokenSupply.limit - tokenSupply.totalSupply) * tokenSupply.priceInCentsPerToken / amountOfCentsTransfered;
		  
		  tokenSupply.totalSupply += tokensPossibleToBuy;
		  tokenAmount += tokensPossibleToBuy;
		  amountOfCentsToBePaid += tokensPossibleToBuy * tokenSupply.priceInCentsPerToken;
		  amountOfCentsTransfered -= amountOfCentsToBePaid;
    }
    
    // Transfer tokens to buyer
    token.transfer(escrow.recipient, tokenAmount);
    
    // Transfer money to seller
	uint amountOfEthToBePaid = amountOfCentsToBePaid * 1 ether / ETH_TO_USD_CENT_EXCHANGE_RATE;
    escrow.seller.transfer(amountOfEthToBePaid);

    // Refund buyer if overpaid
    msg.sender.transfer(msg.value - amountOfEthToBePaid);
  }

  function kill() owneronly {
    suicide(msg.sender);
  }
}