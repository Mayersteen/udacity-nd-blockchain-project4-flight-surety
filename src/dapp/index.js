
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status',
                'Check if contract is operational',
                [ { label: 'Operational Status', error: error, value: result}]
            );
        });


        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // User-submitted transaction
        DOM.elid('submit-buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let price = DOM.elid('insurance-price').value;

            contract.buyInsurance(flight, price, (error, result) => {
                console.log(error, result);
            });

            contract.checkInsuranceStatus(flight, (error,result) => {
                console.log(error, result);
                display('Insurance Status', 'Check if insurance was purchased',
                    [ { label: 'Insurance Status', error: error, value: JSON.stringify(result)}]
                );
            });
        })

        // Check accrued insurance credits
        DOM.elid('claim-credits').addEventListener('click', () => {
            contract.getPayout((error, result) => {
                console.log(error, result);
                display('Claim Insurance Credits', 'Requesting Payout',
                    [ { label: 'Claiming Credits', error: error, value: JSON.stringify(result)} ]
                );
            });
        })

        // Claim credits

    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







