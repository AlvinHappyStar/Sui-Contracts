module sui_raffle::Base {
    // Part 1: imports
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    // Use this dependency to get a type wrapper for UTF-8 strings
    // use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use std::vector;

    /// User doesn't have enough coins to play a round on the suizino
    const ENotEnoughMoney: u64 = 1;
    const ENotEnoughTicket: u64 = 2;

    /// head or tail 2
    const AmountOfCombinations: u8 = 2;

    const Total_reward: u64 =  100;

    struct Game has key {
        id: UID,
        creator: address,
        ticket_price: u64,
        ticket_amount: u64,        
    }

    struct Reward has key{
        id: UID,
        game_id: ID,
        ticket_count: u64,
        balance: Balance<SUI>,
        winner: u8,
    }


    struct RaffleEvent has copy, drop{
        id: ID,
        winner_index:u8,
    }
    /// Ticket represents a participant in a single game.
    /// Can be deconstructed only by the owner.
    struct Ticket has key, store {
        id: UID,
        game_id: ID,
        part_index:u64,
    } 

    struct RaffleOwnership has key, store{
        id: UID
    }

    // initialize our Suizino
    fun init(ctx: &mut TxContext) {
        let admin = @0xf9c5281ec912c083ed150977916919184ecd7d37;

        let game = Game{
            id: object::new(ctx),
            creator: admin,
            ticket_price: 100,
            ticket_amount: 10,
        };
        
        let reward = Reward {
            id: object::new(ctx),
            ticket_count: 0,
            game_id: object::id(&game),
            balance: balance::zero(),
            winner: 0
        };

        transfer::transfer(RaffleOwnership{id: object::new(ctx)}, game.creator);

        transfer::freeze_object(game);
        transfer::share_object(reward);

    }

    // let's play a game
    public entry fun buy_ticket(reward: &mut Reward, game: &Game, wallet: &mut Coin<SUI>, amount: u64, ctx: &mut TxContext){

        // make sure we have enough money to play a game!
        assert!(coin::value(wallet) >= game.ticket_price * amount, ENotEnoughMoney);

        let i = 0;
        while(i < amount)
        {
            reward.ticket_count = reward.ticket_count + 1;
            // make sure ticket_amount is enough
            assert!(game.ticket_amount >= reward.ticket_count, ENotEnoughTicket);            

            // get balance reference
            let wallet_balance = coin::balance_mut(wallet);

            // get money from balance
            let payment = balance::split(wallet_balance, game.ticket_price);

            // add to coinflip's balance.
            balance::join(&mut reward.balance, payment);

            let ticket = Ticket {
                id: object::new(ctx),
                game_id: object::id(game),
                part_index : reward.ticket_count - 1,
            };

            transfer::transfer(ticket, tx_context::sender(ctx));

            i = i + 1;
        };
    }

    public entry fun take_reward(reward: &mut Reward, wallet: &mut Coin<SUI>){

        let payment = balance::split(&mut reward.balance, Total_reward); // get from coinflip's balance.
            // // add fees to admin's wallet
        balance::join(coin::balance_mut(wallet), payment); // add to user's wallet!
    }

    public entry fun draw(_:&RaffleOwnership, reward: &mut Reward, game: &Game, ctx: &mut TxContext)
    {
        let uid = object::new(ctx);

        let randomNums = pseudoRandomNumGenerator(&uid);
        let index = (*vector::borrow(&randomNums, 0)) % (reward.ticket_count as u8);
        

        reward.winner = index;

        let full_balance = balance::value(&reward.balance);
        transfer::transfer(coin::take(&mut reward.balance, full_balance - Total_reward, ctx), game.creator);

        // delete unused id
        object::delete(uid);
    }

    /*
        *** This is not production ready code. Please use with care ***
       Pseudo-random generator. requires VRF in the future to verify randomness! Now it just relies on
       transaction ids.
    */

    fun pseudoRandomNumGenerator(uid: &UID):vector<u8>{

        // create random ID
        let random = object::uid_to_bytes(uid);
        let vec = vector::empty<u8>();

        // add 3 random numbers based on UID of next tx ID.
        vector::push_back(&mut vec, (*vector::borrow(&random, 0) as u8));
        // vector::push_back(&mut vec, (*vector::borrow(&random, 1) as u8) % AmountOfCombinations);
        // vector::push_back(&mut vec, (*vector::borrow(&random, 2) as u8) % AmountOfCombinations);

        vec
    }



    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

}