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

contract TokenEscrow is usingOraclize, IToken {
    string public standard = 'PBKXToken 0.1';
    string public name = 'PBKXToken';
    string public symbol = 'PBKX';
	
	event Burn(address indexed from, uint256 value);

    mapping (address => uint) balanceFor;
	
	address[] addressByIndex;
	
	function balanceOf(address _address) constant returns (uint balance) {
		return balanceFor[_address];
	}
	
	function exchangeToIco(address _icoToken, uint exchangeRate) owneronly {
	    IToken icoToken = IToken(_icoToken);
		for (uint ai = 0; ai < addressByIndex.length; ai++) {
			address currentAddress = addressByIndex[ai];
			icoToken.transfer(currentAddress, balanceFor[currentAddress] * exchangeRate);
			balanceFor[currentAddress] = 0;
		}
	}
	
	function transferFromOwner(address _to, uint256 _value) private returns (bool success) {
        if (balanceFor[owner] < _value) throw;                 // Check if the owner has enough
        if (balanceFor[_to] + _value < balanceFor[_to]) throw;  // Check for overflows
        balanceFor[owner] -= _value;                          // Subtract from the owner
        balanceFor[_to] += _value;                            // Add the same to the recipient
        return true;
    }
	
    function transfer(address _to, uint _value) returns (bool success) {
        if (balanceFor[msg.sender] < _value) throw;           // Check if the sender has enough
        if (balanceFor[_to] + _value < balanceFor[_to]) throw; // Check for overflows
        balanceFor[msg.sender] -= _value;                     // Subtract from the sender
		if (balanceFor[_to] == 0) {
		    addressByIndex.length++;
			addressByIndex[addressByIndex.length-1] = _to;
		}
        balanceFor[_to] += _value;                            // Add the same to the recipient
        return true;
    }
	
	function burn(uint256 _value) returns (bool success) {
        if (balanceFor[msg.sender] < _value) throw;            // Check if the sender has enough
        balanceFor[msg.sender] -= _value;                      // Subtract from the sender
        Burn(msg.sender, _value);
        return true;
    }  
    
  address owner;
  
  uint public ETH_TO_USD_CENT_EXCHANGE_RATE = 32283;
  
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
	
	balanceFor[msg.sender] = 3000000;              // Give the creator all initial tokens
	
	tokenSupplies[0] = TokenSupply(1000000, 0, 20);
	tokenSupplies[1] = TokenSupply(2000000, 0, 30);
	
	// FIXME: enable oraclize_setProof is production
    // oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    update(0);
  }

  struct Escrow {
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
  
  function create(address buyer, address recipient) owneronly {
    escrows[buyer] = Escrow(owner, recipient);
  }

  function create(address buyer) owneronly {
    create(buyer, buyer);
  }

  function min(uint a, uint b) private returns (uint) {
    if (a < b) return a;
    else return b;
  }
  
  // Incoming transfer from the buyer
  function() payable {
    if (ETH_TO_USD_CENT_EXCHANGE_RATE == 0)
      throw;
    
    Escrow escrow = escrows[msg.sender];
    
	uint tokenAmount = 0;
	uint amountOfCentsToBePaid = 0;
	uint amountOfCentsTransfered = msg.value * ETH_TO_USD_CENT_EXCHANGE_RATE / 1 ether;
		
	for (uint discountIndex = 0; discountIndex < 2; discountIndex++) {
		  if (amountOfCentsTransfered <= 0) {
			  break;
		  }
		  TokenSupply tokenSupply = tokenSupplies[discountIndex];
		  uint moneyForTokensPossibleToBuy = min((tokenSupply.limit - tokenSupply.totalSupply) * tokenSupply.priceInCentsPerToken,  amountOfCentsTransfered);
		  uint tokensPossibleToBuy = moneyForTokensPossibleToBuy / tokenSupply.priceInCentsPerToken;
		  
		  tokenSupply.totalSupply += tokensPossibleToBuy;
		  tokenAmount += tokensPossibleToBuy;
		  amountOfCentsToBePaid += tokensPossibleToBuy * tokenSupply.priceInCentsPerToken;
		  amountOfCentsTransfered -= amountOfCentsToBePaid;
    }
    
    // Transfer tokens to buyer
    transferFromOwner(escrow.recipient, tokenAmount);
    
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