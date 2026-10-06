% =========================================================================
% Radix-2 Decimation-in-Frequency (DIF) Fixed-Point FFT Function
% =========================================================================
% Signature:
%   [X, X_int] = fft_radix2_dif(x, N, B, output_order)
%
% Inputs:
%   x            : Input vector (complex or real)
%   N            : FFT length (default = length(x), must be power of 2)
%   B            : Word length in bits (default = 16, e.g. 16, 18, 24)
%   output_order : 'natural' (default, 0..N-1) or 'bitrev' (hardware order)
%
% Outputs:
%   X            : Normalized floating-point spectrum in [-1.0, +1.0]
%   X_int        : Raw signed fixed-point integers in [-2^(B-1), 2^(B-1)-1]
% =========================================================================

function [X, X_int] = fft_radix2_dif(x, N, B, output_order)
    % 1. Default Argument Handling
    if nargin < 2 || isempty(N)
        N = length(x);
    end
    if nargin < 3 || isempty(B)
        B = 16;
    end
    if nargin < 4 || isempty(output_order)
        output_order = 'natural';
    end

    % 2. Validate N (Must be power of 2)
    S = log2(N);
    if floor(S) ~= S || N < 2
        error('FFT length N must be a power of 2 (e.g., 8, 16, 32, 64).');
    end

    % 3. Fixed-Point Limits & Scale Factor
    SCALE = 2^(B - 1);       % 32768 for B=16, 131072 for B=18
    MAX_INT = SCALE - 1;     % +32767 for B=16
    MIN_INT = -SCALE;        % -32768 for B=16

    % 4. Format Input Length (Zero-pad or truncate to N)
    x = x(:).'; % Ensure row vector
    if length(x) < N
        x = [x, zeros(1, N - length(x))];
    elseif length(x) > N
        x = x(1:N);
    end

    % 5. Quantize Input to B-bit Signed Fixed-Point Integers
    data_re = max(MIN_INT, min(MAX_INT, round(real(x) * SCALE)));
    data_im = max(MIN_INT, min(MAX_INT, round(imag(x) * SCALE)));

    % 6. Radix-2 DIF 5-Stage Algorithmic Computation
    for s = 1:S
        len = N / (2^s);      % Butterfly pair distance: 16, 8, 4, 2, 1
        stride = 2 * len;     % Group stride: 32, 16, 8, 4, 2
        tw_step = N / stride; % Twiddle step size

        for start = 1:stride:N
            for k = 0:(len - 1)
                idx_a = start + k;
                idx_b = start + k + len;

                ar = data_re(idx_a);
                ai = data_im(idx_a);
                br = data_re(idx_b);
                bi = data_im(idx_b);

                % Butterfly Addition & Subtraction with Round-Half-Up & /2
                sum_re  = sat_clip(floor((ar + br + 1) / 2), MIN_INT, MAX_INT);
                sum_im  = sat_clip(floor((ai + bi + 1) / 2), MIN_INT, MAX_INT);
                diff_re = sat_clip(floor((ar - br + 1) / 2), MIN_INT, MAX_INT);
                diff_im = sat_clip(floor((ai - bi + 1) / 2), MIN_INT, MAX_INT);

                % Twiddle Factor: W_N^tw_k = cos(theta) - j*sin(theta)
                tw_k = k * tw_step;
                [wr, wi] = get_twiddle(tw_k, N, SCALE, MIN_INT, MAX_INT);

                % Complex Multiplication on Difference Output
                [prod_re, prod_im] = complex_mult_hw(diff_re, diff_im, wr, wi, tw_k, N, SCALE, MIN_INT, MAX_INT);

                % In-Place Update
                data_re(idx_a) = sum_re;
                data_im(idx_a) = sum_im;
                data_re(idx_b) = prod_re;
                data_im(idx_b) = prod_im;
            end
        end
    end

    % 7. Output Ordering (Bit-Reversed vs Natural)
    if strcmpi(output_order, 'natural')
        % Reorder bit-reversed frequency bins into natural order 0..N-1
        rev_map = bit_reverse_indices(N, S);
        out_re = zeros(1, N);
        out_im = zeros(1, N);
        for i = 1:N
            nat_idx = rev_map(i) + 1;
            out_re(nat_idx) = data_re(i);
            out_im(nat_idx) = data_im(i);
        end
    else
        % Raw hardware bit-reversed order
        out_re = data_re;
        out_im = data_im;
    end

    % 8. Format Outputs
    X_int = out_re + 1j * out_im;
    X = X_int / SCALE;
end

%% Helper: Complex Multiplier with Round-Half-Up and Trivial Twiddle Bypasses
function [yr, yi] = complex_mult_hw(xr, xi, wr, wi, tw_k, N, SCALE, MIN_INT, MAX_INT)
    % Hardware Trivial Bypass 1: W^0 = 1 (Wire pass-through)
    if tw_k == 0
        yr = xr;
        yi = xi;
        return;
    end

    % Hardware Trivial Bypass 2: W^(N/4) = -j -> (u + jv)(-j) = v - ju
    if tw_k == (N / 4)
        yr = xi;
        yi = sat_clip(-xr, MIN_INT, MAX_INT);
        return;
    end

    % Four Real Multiplications (Produce 2*B-bit products)
    m1 = double(xr) * double(wr);
    m2 = double(xi) * double(wi);
    m3 = double(xr) * double(wi);
    m4 = double(xi) * double(wr);

    % Cross Subtraction & Addition
    prod_r = m1 - m2;
    prod_i = m3 + m4;

    % Round-Half-Up (+2^(B-2) before shift by B-1)
    half_lsb = SCALE / 2;
    rnd_r = floor((prod_r + half_lsb) / SCALE);
    rnd_i = floor((prod_i + half_lsb) / SCALE);

    yr = sat_clip(rnd_r, MIN_INT, MAX_INT);
    yi = sat_clip(rnd_i, MIN_INT, MAX_INT);
end

%% Helper: Twiddle Factor Generator in B-bit Fixed-Point
function [wr, wi] = get_twiddle(tw_k, N, SCALE, MIN_INT, MAX_INT)
    theta = -2 * pi * tw_k / N;
    wr = sat_clip(round(cos(theta) * SCALE), MIN_INT, MAX_INT);
    wi = sat_clip(round(sin(theta) * SCALE), MIN_INT, MAX_INT);
end

%% Helper: Saturation Clamp
function y = sat_clip(x, min_val, max_val)
    y = max(min_val, min(max_val, x));
end

%% Helper: Bit-Reversal Index Map
function rev_map = bit_reverse_indices(N, S)
    rev_map = zeros(1, N);
    for x = 0:(N - 1)
        r = 0;
        for i = 0:(S - 1)
            if bitand(x, bitshift(1, i)) > 0
                r = bitor(r, bitshift(1, S - 1 - i));
            end
        end
        rev_map(x + 1) = r;
    end
end
