#include <math.h>
#include <complex.h>

#include <cblas.h>
#include <fftw3.h>

void dumpD(double* mem, int length) {
    for (int j = 0; j < length; ++j) {
        printf("%.7lf\n", mem[j]);
    }
}

void dumpDC(double _Complex* mem, int length) {
    for (int j = 0; j < length; ++j) {
        printf("%.7lf + %.7lfi\n", creal(mem[j]), cimag(mem[j]));
    }
}

double* hanning(int length) {
    double* result = fftw_alloc_real(length);

    for (int j = 0; j < length; ++j) {
        double elem = 0.5 * (1-(cos(j*2*M_PI / (double)(length - 1))));
        result[j] = elem / (double)length;
    }

    return result;
}

fftw_complex* tempKernel(double Q, int length) {
    fftw_complex* result = fftw_alloc_complex(length);

    for (int j = 0; j < length; ++j) {
        fftw_complex elem = cexp(2*M_PI*_Complex_I*Q*j / (double)length);
        result[j] = elem;
    }

    return result;
}

void elementMultiply(double* in, fftw_complex* in2, fftw_complex* out,
        int length) {
    for (int j = 0; j < length; ++j) {
        fftw_complex elem = in[j] * in2[j];
        out[j] = elem;
    }
}

double q(int bins) {
    return 1 / (exp2(1 / (double)bins) - 1);
}

int k(int minFreq, int maxFreq, int bins) {
    return rint(ceil(bins * log2((double)maxFreq / (double)minFreq)));
}

int fftLen(double q_, int minFreq, int sampleRate) {
    return rint(exp2(ceil(log2(q_ * sampleRate / (double) minFreq))));
}

void zeroThresh(double _Complex* matrix, int length, double thresh) {
    fftw_complex zero = 0.0 + 0.0*_Complex_I;
    for (int j = 0; j < length; ++j) {
        if (cabs(matrix[j]) <= thresh)
            matrix[j] = zero;
    }
}

void swapColumn(double _Complex* matrix, int height, int width,
        double _Complex* vector, int index) {
    for (int j = 0; j < height; ++j) {
        matrix[j * width + index] = vector[j];
    }
}

fftw_complex* kernel(int minFreq, int maxFreq, int sampleRate, int bins,
        int* height, int* width) {

    double Q = q(bins);
    int K = k(minFreq, maxFreq, bins);
    int fft = fftLen(Q, minFreq, sampleRate);

    fftw_complex* temp = fftw_alloc_complex(fft);
    fftw_complex* spec = fftw_alloc_complex(fft);
    fftw_complex* result = fftw_alloc_complex(fft * K);
    fftw_plan plan = fftw_plan_dft_1d(fft, temp, spec, FFTW_FORWARD,
            FFTW_ESTIMATE);

    for (int j = K-1; j >= 0; --j) {
        int len = ceil(Q*sampleRate/(minFreq*exp2(j/(double)bins)));

        double* h = hanning(len);
        fftw_complex* vec = tempKernel(Q, len);

        // temp = h .* vec
        elementMultiply(h, vec, temp, len);

        // spec = fft(temp)
        fftw_execute(plan);

        zeroThresh(spec, fft, 0.0054);
        swapColumn(result, fft, K, spec, j);

        fftw_free(h);
        fftw_free(vec);
    }

    fftw_destroy_plan(plan);
    fftw_free(temp);
    fftw_free(spec);

    for (int j = 0; j < fft * K; ++j) {
        result[j] = conj(result[j]) / (double)fft;
    }

    *height = fft;
    *width = K;
    return result;
}

fftw_complex* constQTransform(double* data, fftw_complex* kernel,
        int height, int width) {
    fftw_complex* fft = fftw_alloc_complex(height);
    fftw_plan plan = fftw_plan_dft_r2c_1d(height, data, fft, FFTW_ESTIMATE);
    fftw_execute(plan);

    // fill redundant data
    for (int j = 0; j < height / 2 - 1; ++j) {
        fft[height - j - 1] = conj(fft[j + 1]);
    }

    fftw_complex* result = fftw_alloc_complex(width);

    double _Complex one = 1.0;
    double _Complex zero = 0.0;
    cblas_zgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
        1, width, height,
        &one,
        fft, height,
        kernel, width,
        &zero,
        result, width);

    fftw_free(fft);
    fftw_destroy_plan(plan);

    return result;
}

int main() {
    FILE* f = fopen("output", "r");
    double* data = fftw_alloc_real(16384);
    double num;

    int i = 0;
    while(fscanf(f, "%lf\n", &num) > 0)
        data[i++] = num;

    int fft,K;
    fftw_complex* vec = kernel(55, 880, 44100, 12, &fft, &K);
    fftw_complex* cq = constQTransform(data, vec, fft, K);
    dumpDC(cq, K);

    fftw_free(vec);
    fftw_free(cq);
    fftw_free(data);
    fclose(f);

    return 0;
}
