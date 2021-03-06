function output = runthis(cnstl,num_intf,num_intfA)

% EE6343 Final Project - Fall 2009
% John W. Thomas and Trevor Toland - University of Texas at Dallas

%close all
clc

%cnstl = '04PSK'; 			% Now a function parameter
trials=10;	            		% # of trials for better averaging
%SNRdB = [-10 0 10 ];  			% SNR (dB), smaller range
SNRdB = [-10 -7 -5 0 5 7 10 15 20 ];  	% SNR (dB), small range
%SNRdB = -10:30;    			% SNR (dB), large range
N=48;                 			% # of symbols per trial

nUSC=48;				% # of used subcarriers out of 80
nSamples = 80;             		% # of samples/symbol
rows = ceil(N/nUSC);			% # of rows in matrix form of symbols

%num_intf = 1;               		% # of synchronous interferers
%num_intfA = 1;               		% # of asynchronous interferers

%%----  File name prefix ---%%
savetxt = ['OFDM_Simulation_', cnstl, '_', num2str(num_intf), 'x', num2str(num_intfA), '_intf' ]

%%--- Data Initialization ---%%
BER=zeros(2,length(SNRdB));		% BER for AWGN channel - 2-D for w and w/o interference
intf = {}; 				% Sync Interference sum class
intfA = {}; 				% Async Interference sum class


for k=1:length(SNRdB);			% SNR Loop
    display(['SNR(dB): ', num2str(SNRdB(k))])
    noisevar=10^(-SNRdB(k)/10);  	% noise variance from the SNR assuming Es=1(symbol energy)
    for tri=1:trials;			% trials Loop
  	display(['Trial #: ', num2str(tri)])
        
	%%--- Data ---%%
        [x1 b] = modulator2(cnstl,N);  	% array of N random symbols - TX
        x = OFDM_DFT(x1,N,'TX');  	% IFFT - TX - size=10x80
        size(x);
	
        %%--- Received Pilots ---%%
        pilots_x = x(1:rows:nUSC);
	size(pilots_x);
        
        %%--- Synchronous Interference ---%%
        for f=1:num_intf
            [intf1 a] = modulator2(cnstl,N);  	% array of random symbols at TX
            intf{f} = OFDM_DFT(0.3.*intf1,N,'TX');  	% interference class - IFFT - TX - size=10x80
        end

	%%--- Asynchronous Interference ---%%
	for f=1:num_intfA
	    [intf1 a] = modulator2(cnstl,N);    		% array of random symbols at TX
	    delay = unifrnd(1,40) * 50 * 10^-9; 		% time delay - uniform dist (1-50 samples)
	    intfA{f} = OFDM_DFT(0.3.*intf1,N,'TX');   		% interference class - IFFT - TX - size=10x80
	    intfA{f} =  intfA{f} .* exp(-2i*pi*delay);
	end

        %%--- Complex Gaussian Noise  ---%%
        noise=(randn(rows,nSamples)+1i*randn(rows,nSamples))/sqrt(2);  % complex Gaussian Noise
        size(noise);
        
        %%--- AWGN ---%%
        y1= x + sqrt(noisevar)*noise;  			% AWGN channel - no interference
        yI1 = y1;
        for f=1:num_intf
            yI1= yI1 + sqrt(noisevar)*intf{f};  	% AWGN channel - synch interference
        end
	for f=1:num_intfA
	    yI1= yI1 + sqrt(noisevar)*intfA{f};         % AWGN channel - asynch interference
        end

        size(y1);
        y = OFDM_DFT(y1,N,'RX');  			% FFT at RX
        yI = OFDM_DFT(yI1,N,'RX');  			% FFT at RX
        size(y);
        
        %%--- Received Pilots ---%%
        pilots_yI = yI(1,:);

	%%--- Channel Estimation ---%%
	if tri == 1
	    h_newI = pilots_yI ./ pilots_x;
	else
	    sigma = sqrt(noisevar);
	    h_oldI = h_newI;
	    h_newI = NPML_chan_est(pilots_x, pilots_yI, h_oldI, sigma, nUSC);
	end
	
 	%%--- ML Receiver ---%%
	xhatI = MLreceiver(yI, h_newI, noisevar,cnstl) ;

	yI = reshape(xhatI,1,N);
	bhat = demodulator2(y, cnstl);        		% Receiver for AWGN channel
        bhatI = demodulator2(xhatI, cnstl);            	% Receiver for AWGN + interference channel
        
        size(b);
	b;
        size(bhat);
	bhat;
        size(bhatI);
	bhatI;

        [num, err] = biterr(b,bhat);
        [numI, errI] = biterr(b,bhatI);

	BER(1,k)= BER(1,k) + err;          % error count for AWGN
        BER(2,k)= BER(2,k) + errI;          % error count for AWGN
   
   end

end

figure
semilogy(SNRdB,BER(1,:)/trials,'-r^');
hold on;
semilogy(SNRdB,BER(2,:)/trials,'-ko');
hold off;

title([ cnstl,  ' Performace ']) 
ylabel('BER')
xlabel('Avg. SINR per RX Antenna (dB)')
legend('AWGN - 0 interferers', ['AWGN - ',num2str(num_intf),' synch ', num2str(num_intfA), ' asynch interferers']);

save(savetxt)
saveas(gcf, [savetxt, '.fig'])
save2pdf(savetxt,gcf,600);

clear all
