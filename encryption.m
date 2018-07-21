function imagePlusPlus = encryption(image, fileName)
%This function takes in a message, and attempts to hide it inside of an
%image
%   INPUTS:
%       image: The name of the file we will be hiding a message in.  It
%       needs to be a .png or .jpg file and should be named accordingly.
%       fileName: The name of the file we want to hide.  This program
%       supports the encryption of text files and wav files.  If the file
%       does not have a '.txt' or '.wav' suffix an error will occur.  Audio
%       files can have any sample rate, but faster rates decreases the
%       length of the largest storeable message.
%   OUTPUTS:
%       This function will output an image in the form of a three
%       dimensional image matrix.  We also have the option of saving the 
%       file directly to the directory after inputting a file name.
% In order to hide the message we only need to know that it is
% significantly smaller than the image we'll be hiding it in.  Audio files
% in particular will need to be relatively short, as they have significant
% overhead as each sample point needs almost 22 pixels to be fully encoded
% NOTE: If the image is compressed in any way, the message will be lost

%%Input Control
%Make sure we have the correct number of inputs
if nargin ~= 2
    error('Please input the name of your text file and your message file.');
end
%Make sure we actually got an image to hide.
if length(image) < 5 || ~any(all(image(end-3:end) == '.png') || all(image(end-3:end) == '.jpg'))
    error('Please only use jpgs and pngs as your image files. Name them accordingly.');
end

%%Import our files.  Once we're sure we have the image, import it and turn
%%it into a uint8
image = imread(image);
%Process the input message according to the input files type

%If the message is a text file,
if all(fileName(end-3:end) == '.txt')
    %First read all of the characters from the text file
    message = fileread(fileName);
    %Then turn all of the characters into their ascii values
    message = uint8(message);
    %Once I have my message in a set of uint8s, get the representative binary
    message = dec2bin(message,8);
%If the message is a wav file
elseif all(fileName(end-3:end) == '.wav')
    %Read in the wav file and its sample rate
    [message,sampleRate] = audioread(fileName);

    %Call function to turn the floating point number to binary.  This
    %function will turn all of the binary information into one vector that
    %needs to be reshaped and in order to be the correct binary
    %representation.  This function only works on one element at a time
    binMessage = char(ones(size(message,1),64));
    for g = 1:size(message,1)
        binMessage(g,:) = float2bin(message(g));
    end
    
    %We know have 64 bit entries, but we want them to be in eight bits.
    %This reshaping will put break each 64 bit number into 8 consecutive 8
    %bit numbers
    message = reshape(binMessage',8,max(cumprod(size(binMessage)))/8)'; 
    
    %In order to get the message out at the end, we need to get the final
    %sample rate of the audio file.  Turn the number into its
    %representative characters and hide it on top of the message
    %information hidden behind a period
    rate = dec2bin(num2str(sampleRate),8);
    message = [rate; dec2bin(uint8(['.' fileName]),8); message];
    
end

%Addition of File Name at the begining of the message
message = [dec2bin(uint8(['.' fileName]),8); message];

%We will be marking the length of the message by adding chars at the
%begining. Exe if we store 54 bytes, '5''4' will be stored in the message.
rows = dec2bin(num2str(size(message,1)),8);
if(size(rows,1)>7)
   error('This message is by convention too large for us to decode. Sorry.') 
end
message = [rows; message];

%%Confirmation That we Have Enough Space
%We will store a single bit of our message in each R, G and B frame of our
%image until we have stored the entire message.  This means we need to make
%sure the total number of pixels > the number of bits in our message
bitsToEncode = max(cumprod(size(message)));
if(max(cumprod(size(image))) < bitsToEncode)
   error('your message is too large to be hidden in this image')
end

%%Begin hiding the message one bit at a time.  We'll encode directly down
%%the image moving through all three color dimensions and then moving down
%%the columns from the top to the bottom and from left to right through the
%%rows. We will only alter the LSB of each set to minimize our impact on
%%the image.

%First permute the image so the RGB columns are the most significant.
%Allowing us to trivially index the image.
permedIm = permute(image,[3 1 2]);
%Take the transpose of the message in order to index it trivially as well
messageTranspose = message';

%Go through the image from index 1 until the entire message is hidden
for k = 1 : bitsToEncode 
    %My original method of reading the bit involved some modular math. I
    %later realized that this was needlessly complicated and I could just
    %pull the bit from the transpose of the message significantly reducing
    %the amount of function calls I needed per encryption
    %bit = message(floor((k-1)/size(message,2))+1,mod(k-1,size(message,2))+1);
    
    bit = messageTranspose(k);
    %If the bit is a one, use the or operation to ensure the LSB of the
    %image is high at this point.
    if(bit == '1')
        permedIm(k) = bitor(permedIm(k),1);
    
    %If the bit is a zero, use the bitand operation to turn off the bit. We
    %know that 2^7=8 - 1 = our max value of 256, subtracting one will ensure
    %the first bit is low.  So bitand the value with 254
    else
        permedIm(k) = bitand(permedIm(k),uint8(254));
    end
end

%Now that we have finished encoding the image, we need to put it back into
%its standard format.
imagePlusPlus = permute(permedIm,[2 3 1]);

%Ask the user if they would like to save the file.
response = input('Would you like us to save the image? Type ''y'' for yes or 0 ''n'' for no:  ');
if(response == 'y')
    response = input('What would you like to name the file? Do not include a suffix:  ');
    %We need to write as a bmp file or the compression will ruin our
    %message
    imwrite(imagePlusPlus,[response '.bmp'], 'bmp');
end
end

function b = float2bin(f)
%This function converts a floating point number to a binary string.
%
%Input: f - floating point number, either double or single
%Output: b - string of "0"s and "1"s in IEEE 754 floating point format
%
%Floating Point Binary Formats
%Single: 1 sign bit, 8 exponent bits, 23 significand bits
%Double: 1 sign bit, 11 exponent bits, 52 significand bits
%
%Programmer: Eric Verner
%Organization: Matlab Geeks
%Website: matlabgeeks.com
%Email: everner@matlabgeeks.com
%Date: 22 Oct 2012
%
%I allow the use and modification of this code for any purpose.

    %Input checking
    if ~isfloat(f)
      disp('Input must be a floating point number.');
      return;
    end

    hex = '0123456789abcdef'; %Hex characters

    h = num2hex(f);	%Convert from float to hex characters

    hc = num2cell(h); %Convert to cell array of chars

    nums =  cellfun(@(x) find(hex == x) - 1, hc); %Convert to array of numbers

    bins = dec2bin(nums, 4); %Convert to array of binary number strings

    b = reshape(bins.', 1, numel(bins)); %Reshape into horizontal vector
end