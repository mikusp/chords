#include <stdlib.h>
#include <math.h>
#include <complex.h>

#include <cs.h>
#include <fftw3.h>

void cq_dump_vector(const double* vec, int length) {
    for (int j = 0; j < length; ++j) {
        printf("%.7lf\n", vec[j]);
    }
}

void cq_dump_vector_complex(const double _Complex* vec, int length) {
    for (int j = 0; j < length; ++j) {
        printf("%.7lf + %.7lfi\n", creal(vec[j]), cimag(vec[j]));
    }
}

void cq_dump_matrix_abs(const double _Complex* matrix, int height, int width) {
    for (int j = 0; j < height; ++j) {
        for (int k = 0; k < width; ++k)
            printf("%.7lf ", cabs(matrix[j * width + k]));

        printf("\n");
    }
}

double* cq_hanning_window(int length) {
    double* result = fftw_alloc_real(length);

    for (int j = 0; j < length; ++j) {
        double elem = 0.5 * (1-(cos(j*2*M_PI / (double)(length - 1))));
        result[j] = elem / (double)length;
    }

    return result;
}

fftw_complex* cq_temp_kernel(double Q, int length) {
    fftw_complex* result = fftw_alloc_complex(length);

    for (int j = 0; j < length; ++j) {
        fftw_complex elem = cexp(2*M_PI*_Complex_I*Q*j / (double)length);
        result[j] = elem;
    }

    return result;
}

void cq_multiply_vector_elem(const double* in, const fftw_complex* in2,
        fftw_complex* out, int length) {
    for (int j = 0; j < length; ++j) {
        fftw_complex elem = in[j] * in2[j];
        out[j] = elem;
    }
}

double cq_q(int bins) {
    return 1 / (exp2(1 / (double)bins) - 1);
}

int cq_k(int min_freq, int max_freq, int bins) {
    return rint(ceil(bins * log2((double)max_freq / (double)min_freq)));
}

int cq_fft_len(double q, int min_freq, int sample_rate) {
    return rint(exp2(ceil(log2(q * sample_rate / (double) min_freq))));
}

void cq_zero_vector_below_thresh(double _Complex* vec, int length,
        double thresh) {
    fftw_complex zero = 0.0 + 0.0*_Complex_I;
    for (int j = 0; j < length; ++j) {
        if (cabs(vec[j]) <= thresh)
            vec[j] = zero;
    }
}

void cq_swap_matrix_column(double _Complex* matrix, int height, int width,
        const double _Complex* vector, int index) {
    for (int j = 0; j < height; ++j) {
        matrix[j * width + index] = vector[j];
    }
}

cs_ci* cq_make_kernel(int min_freq, int max_freq, int sample_rate,
        int bins, int* height, int* width) {
    double Q = cq_q(bins);
    int K = cq_k(min_freq, max_freq, bins);
    int fft = cq_fft_len(Q, min_freq, sample_rate);

    fftw_complex* temp = fftw_alloc_complex(fft);
    fftw_complex* spec = fftw_alloc_complex(fft);
    cs_ci* result = cs_ci_spalloc(fft, K, (int)(fft*K*0.01), 1, 1);
    fftw_plan plan = fftw_plan_dft_1d(fft, temp, spec, FFTW_FORWARD,
            FFTW_ESTIMATE);

    for (int j = K-1; j >= 0; --j) {
        int len = ceil(Q*sample_rate/(min_freq*exp2(j/(double)bins)));

        double* h = cq_hanning_window(len);
        fftw_complex* vec = cq_temp_kernel(Q, len);

        // temp = h .* vec
        cq_multiply_vector_elem(h, vec, temp, len);

        // spec = fft(temp)
        fftw_execute(plan);

        cq_zero_vector_below_thresh(spec, fft, 0.0054);

        for (int k = 0; k < fft; ++k) {
            fftw_complex temp = spec[k];
            if (cabs(temp) > 0.0001)
                cs_ci_entry(result, k, j, conj(temp) / (double)fft);
        }

        fftw_free(h);
        fftw_free(vec);
    }

    fftw_destroy_plan(plan);
    fftw_free(temp);
    fftw_free(spec);

    cs_ci* ret = cs_ci_compress(result);
    cs_ci_spfree(result);
    *height = fft;
    *width = K;
    return ret;
}

fftw_complex* cq_const_q_transform(double* data, const cs_ci* kernel,
        int height, int width, const fftw_plan plan, fftw_complex* buffer) {
    fftw_execute_dft_r2c(plan, data, buffer);

    // fill redundant data
    for (int j = 0; j < height / 2 - 1; ++j) {
        buffer[height - j - 1] = conj(buffer[j + 1]);
    }

    fftw_complex* result = fftw_alloc_complex(width);

    for (int j = 0; j < width; ++j) {
        result[j] = 0;
    }

    cs_ci_gaxpy(kernel, buffer, result);

    return result;
}

fftw_complex* cq_const_q_wrap(double* data, const cs_ci* kernel, int height,
        int width, const int* indices, int indices_size) {
    fftw_complex* temp_fft = fftw_alloc_complex(height);
    fftw_plan plan = fftw_plan_dft_r2c_1d(height, data, temp_fft, FFTW_ESTIMATE |
            FFTW_PRESERVE_INPUT);

    fftw_complex* result = fftw_alloc_complex(height * indices_size);

    for (int j = 0; j < indices_size; ++j) {
        fftw_complex* cq = cq_const_q_transform(data + indices[j], kernel,
            height, width, plan, temp_fft);

        cq_swap_matrix_column(result, width, indices_size, cq, j);
        fftw_free(cq);
    }

    fftw_free(temp_fft);
    fftw_destroy_plan(plan);
    return result;
}

fftw_complex* cq_short_time_constq_transform(double* data, int data_length,
        int min_freq, int max_freq, int sample_rate, int bins, int step,
        int* height,  int* width) {
    int kernel_height, kernel_width;
    cs_ci* ker = cq_make_kernel(min_freq, max_freq, sample_rate, bins,
        &kernel_height, &kernel_width);
    cs_ci* kern = cs_ci_transpose(ker, 1);

    int max_index = rint(ceil(data_length / kernel_height));

    int indices_size = (max_index - 1) * kernel_height / (double) step + 1;
    int* indices = (int*) malloc(indices_size * sizeof(int));
    for (int j = 0, k = 0; j <= (max_index - 1) * kernel_height; ++k, j += step)
        indices[k] = j;

    fftw_complex* result = cq_const_q_wrap(data, kern, kernel_height,
            kernel_width, indices, indices_size);

    cs_ci_spfree(ker);
    cs_ci_spfree(kern);
    free(indices);

    *height = kernel_width;
    *width = indices_size;
    return result;
}

